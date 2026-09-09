import 'dart:convert';

import 'package:sqflite_common/sqlite_api.dart';
import 'package:uuid/uuid.dart';

import '../money/currency.dart';
import '../money/money.dart';
import 'ledger_errors.dart';
import 'ledger_models.dart';
import 'tx_type.dart';

/// Clock abstraction so tests control "now".
typedef Clock = DateTime Function();

/// The ONLY writer of the `transactions` table.
/// Implements docs/04_LEDGER_RULES.md R1–R10.
class LedgerService {
  final Database _db;
  final String shopId;
  final String deviceId;
  final Clock _now;
  final Uuid _uuid = const Uuid();

  /// Tolerance for clock skew when rejecting future dates (R7).
  static const futureTolerance = Duration(minutes: 5);

  LedgerService({
    required Database db,
    required this.shopId,
    required this.deviceId,
    Clock? clock,
  })  : _db = db,
        _now = clock ?? (() => DateTime.now().toUtc());

  // ---------------------------------------------------------------------------
  // Recording
  // ---------------------------------------------------------------------------

  /// Records a transaction. Throws a [LedgerError] on any rule violation.
  Future<LedgerTx> record(NewTransaction input, Actor actor) async {
    // R2 / edge #2,#3
    if (input.amount.minor <= 0) throw const InvalidAmountError();

    // R9 / ownerOnly types
    if (input.type.ownerOnly && !actor.canAdjust) throw const PermissionError();

    // edge #4 — currency must be active
    if (!await _isCurrencyActive(input.amount.currency.code)) {
      throw InactiveCurrencyError(input.amount.currency.code);
    }

    final now = _now();
    final occurredAt = (input.occurredAt ?? now).toUtc();

    // R7 / edge #10 — no future
    if (occurredAt.isAfter(now.add(futureTolerance))) throw const FutureDateError();

    // R7 / edge #11 — locked period
    final lockedBefore = await _lockedBefore();
    var inLocked = false;
    if (lockedBefore != null && occurredAt.isBefore(lockedBefore)) {
      if (!actor.canBackdateIntoLocked ||
          (input.lockedReason == null || input.lockedReason!.trim().isEmpty)) {
        throw const LockedPeriodError();
      }
      inLocked = true;
    }

    // customer
    final cust = await _customer(input.customerId);
    if (cust == null) throw const CustomerNotFoundError();
    final archived = (cust['is_archived'] as int) == 1;
    // edge #13 — archived: only credit (paying off) is allowed
    if (archived && input.type != TxType.credit) throw const CustomerArchivedError();

    // edge #12 — one opening per customer+currency
    if (input.type == TxType.opening) {
      final exists = await _db.rawQuery(
        "SELECT 1 FROM transactions WHERE customer_id=? AND currency_code=? AND type='opening' AND reversed_by_id IS NULL LIMIT 1",
        [input.customerId, input.amount.currency.code],
      );
      if (exists.isNotEmpty) throw const OpeningAlreadyExistsError();
    }

    // edge #14 — credit limit (allowed, flagged)
    var overLimit = false;
    if (input.type.sign > 0 &&
        cust['credit_limit_minor'] != null &&
        cust['credit_limit_currency'] == input.amount.currency.code) {
      final current = await balance(input.customerId, input.amount.currency);
      final after = current.balance + input.amount;
      if (after.minor > (cust['credit_limit_minor'] as int)) overLimit = true;
    }

    final id = _uuid.v4();
    final seq = await _nextSeq();

    final row = <String, Object?>{
      'id': id,
      'shop_id': shopId,
      'customer_id': input.customerId,
      'type': input.type.dbValue,
      'amount_minor': input.amount.minor,
      'currency_code': input.amount.currency.code,
      'occurred_at': occurredAt.millisecondsSinceEpoch,
      'recorded_at': now.millisecondsSinceEpoch,
      'recorded_by': actor.userId,
      'note_text': input.noteText,
      'note_voice_path': input.noteVoicePath,
      'receipt_photo_path': input.receiptPhotoPath,
      'due_date': input.dueDate?.toUtc().millisecondsSinceEpoch,
      'reverses_id': null,
      'reversed_by_id': null,
      'reversal_reason': inLocked ? input.lockedReason : null,
      'customer_name_snap': cust['name'] as String,
      'user_name_snap': actor.name,
      'fx_rate_snap': null,
      'over_limit': overLimit ? 1 : 0,
      'in_locked_period': inLocked ? 1 : 0,
      'device_id': deviceId,
      'local_seq': seq,
    };

    await _db.transaction((txn) async {
      await txn.insert('transactions', row);
      await txn.update(
        'customers',
        {'last_activity_at': now.millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [input.customerId],
      );
      await _audit(txn, 'transaction', id, 'record', actor.userId, null, row, now);
    });
    await _refreshCache(input.customerId, input.amount.currency);
    return (await getById(id))!;
  }

  /// R1/R9 — reverse an existing transaction with a new opposite entry.
  Future<LedgerTx> reverse(String txId, Actor actor, {required String reason}) async {
    if (!actor.canReverse) throw const PermissionError();
    if (reason.trim().isEmpty) throw const ReasonRequiredError();

    final original = await getById(txId);
    if (original == null) throw const TransactionNotFoundError();
    if (original.isReversed) throw const AlreadyReversedError();
    if (original.isReversal) throw const CannotReverseReversalError();

    final now = _now();
    final id = _uuid.v4();
    final seq = await _nextSeq();

    final row = <String, Object?>{
      'id': id,
      'shop_id': shopId,
      'customer_id': original.customerId,
      'type': original.type.reverse.dbValue,
      'amount_minor': original.amount.minor,
      'currency_code': original.amount.currency.code,
      'occurred_at': now.millisecondsSinceEpoch,
      'recorded_at': now.millisecondsSinceEpoch,
      'recorded_by': actor.userId,
      'note_text': 'إلغاء حركة: ${original.type.labelAr}',
      'reverses_id': original.id,
      'reversed_by_id': null,
      'reversal_reason': reason.trim(),
      'customer_name_snap': original.customerNameSnap,
      'user_name_snap': actor.name,
      'over_limit': 0,
      'in_locked_period': 0,
      'device_id': deviceId,
      'local_seq': seq,
    };

    await _db.transaction((txn) async {
      await txn.insert('transactions', row);
      // The single permitted UPDATE (see trigger in schema.dart).
      final n = await txn.update(
        'transactions',
        {'reversed_by_id': id},
        where: 'id = ? AND reversed_by_id IS NULL',
        whereArgs: [original.id],
      );
      if (n != 1) throw const AlreadyReversedError();
      await _audit(txn, 'transaction', original.id, 'reverse', actor.userId,
          {'reversed_by_id': null}, {'reversed_by_id': id, 'reason': reason}, now);
    });
    await _refreshCache(original.customerId, original.amount.currency);
    return (await getById(id))!;
  }

  // ---------------------------------------------------------------------------
  // Reading
  // ---------------------------------------------------------------------------

  Future<LedgerTx?> getById(String id) async {
    final rows = await _db.query('transactions', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : LedgerTx.fromRow(rows.first);
  }

  /// R3 — computed from non-reversed, non-reversal entries.
  /// (Excluding both sides of a reversal pair is equivalent to including both;
  /// we exclude for clarity and so `tx_count` reflects "live" entries.)
  Future<CustomerBalance> balance(String customerId, Currency currency) async {
    final r = await _db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE type
          WHEN 'debit' THEN amount_minor
          WHEN 'adjust_up' THEN amount_minor
          WHEN 'opening' THEN amount_minor
          WHEN 'credit' THEN -amount_minor
          WHEN 'adjust_down' THEN -amount_minor
        END), 0) AS bal,
        COUNT(*) AS cnt,
        MAX(occurred_at) AS last_at
      FROM transactions
      WHERE customer_id = ? AND currency_code = ?
        AND reversed_by_id IS NULL AND reverses_id IS NULL
    ''', [customerId, currency.code]);
    final row = r.first;
    return CustomerBalance(
      customerId: customerId,
      balance: Money((row['bal'] as int?) ?? 0, currency),
      txCount: (row['cnt'] as int?) ?? 0,
      lastTxAt: row['last_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row['last_at'] as int, isUtc: true),
    );
  }

  /// All balances (one per currency) for a customer, only currencies with activity.
  Future<List<CustomerBalance>> balancesAllCurrencies(String customerId) async {
    final codes = await _db.rawQuery(
      'SELECT DISTINCT currency_code FROM transactions WHERE customer_id = ?',
      [customerId],
    );
    final out = <CustomerBalance>[];
    for (final c in codes) {
      out.add(await balance(customerId, Currency.byCode(c['currency_code'] as String)));
    }
    return out;
  }

  /// Shop-wide total owed (positive balances only) per currency — hero card.
  Future<Map<Currency, Money>> totalOwedByCurrency() async {
    final rows = await _db.rawQuery('''
      SELECT currency_code, SUM(bal) AS total FROM (
        SELECT customer_id, currency_code,
          SUM(CASE type
            WHEN 'debit' THEN amount_minor WHEN 'adjust_up' THEN amount_minor WHEN 'opening' THEN amount_minor
            WHEN 'credit' THEN -amount_minor WHEN 'adjust_down' THEN -amount_minor END) AS bal
        FROM transactions
        WHERE reversed_by_id IS NULL AND reverses_id IS NULL
        GROUP BY customer_id, currency_code
      ) WHERE bal > 0 GROUP BY currency_code
    ''');
    return {
      for (final r in rows)
        Currency.byCode(r['currency_code'] as String):
            Money((r['total'] as int?) ?? 0, Currency.byCode(r['currency_code'] as String))
    };
  }

  /// Statement for a period. `from` inclusive, `to` inclusive (end of day handled by caller).
  /// Edge #17: opening = balance strictly before `from`; closing = opening + period.
  Future<Statement> statement({
    required String customerId,
    required Currency currency,
    required DateTime from,
    required DateTime to,
    bool includeReversed = false,
  }) async {
    final f = from.toUtc().millisecondsSinceEpoch;
    final t = to.toUtc().millisecondsSinceEpoch;

    final openRow = await _db.rawQuery('''
      SELECT COALESCE(SUM(CASE type
        WHEN 'debit' THEN amount_minor WHEN 'adjust_up' THEN amount_minor WHEN 'opening' THEN amount_minor
        WHEN 'credit' THEN -amount_minor WHEN 'adjust_down' THEN -amount_minor END),0) AS bal
      FROM transactions
      WHERE customer_id=? AND currency_code=? AND occurred_at < ?
        AND reversed_by_id IS NULL AND reverses_id IS NULL
    ''', [customerId, currency.code, f]);
    final opening = Money((openRow.first['bal'] as int?) ?? 0, currency);

    final liveFilter = includeReversed ? '' : 'AND reversed_by_id IS NULL AND reverses_id IS NULL';
    final rows = await _db.rawQuery('''
      SELECT * FROM transactions
      WHERE customer_id=? AND currency_code=? AND occurred_at BETWEEN ? AND ? $liveFilter
      ORDER BY occurred_at ASC, recorded_at ASC, rowid ASC
    ''', [customerId, currency.code, f, t]);

    var running = opening;
    var td = Money.zero(currency);
    var tc = Money.zero(currency);
    var ta = Money.zero(currency);
    final lines = <StatementLine>[];
    for (final r in rows) {
      final tx = LedgerTx.fromRow(r);
      final live = !tx.isReversed && !tx.isReversal;
      if (live) {
        running = running + tx.signedEffect;
        switch (tx.type) {
          case TxType.debit:
          case TxType.opening:
            td = td + tx.amount;
          case TxType.credit:
            tc = tc + tx.amount;
          case TxType.adjustDown:
            ta = ta - tx.amount;
          case TxType.adjustUp:
            ta = ta + tx.amount;
        }
      }
      lines.add(StatementLine(tx, running));
    }
    return Statement(
      customerId: customerId,
      currency: currency,
      from: from,
      to: to,
      opening: opening,
      lines: lines,
      closing: running,
      totalDebit: td,
      totalCredit: tc,
      totalAdjust: ta,
    );
  }

  /// Recent transactions (for the home row / lists). Paged.
  /// `liveOnly` excludes reversed originals and reversal entries in SQL so a
  /// page of N always yields N live rows (audit gap #5).
  Future<List<LedgerTx>> recent({
    int limit = 20,
    int offset = 0,
    String? customerId,
    bool liveOnly = false,
  }) async {
    final conds = <String>[];
    final args = <Object?>[];
    if (customerId != null) {
      conds.add('customer_id = ?');
      args.add(customerId);
    }
    if (liveOnly) conds.add('reversed_by_id IS NULL AND reverses_id IS NULL');
    final where = conds.isEmpty ? '' : 'WHERE ${conds.join(' AND ')}';
    args.addAll([limit, offset]);
    final rows = await _db.rawQuery('''
      SELECT * FROM transactions $where
      ORDER BY occurred_at DESC, recorded_at DESC, rowid DESC
      LIMIT ? OFFSET ?
    ''', args);
    return rows.map(LedgerTx.fromRow).toList();
  }

  // ---------------------------------------------------------------------------
  // Integrity (R3)
  // ---------------------------------------------------------------------------

  /// Rebuild the whole balances_cache from transactions.
  Future<void> rebuildCache() async {
    final now = _now().millisecondsSinceEpoch;
    await _db.transaction((txn) async {
      await txn.delete('balances_cache');
      await txn.execute('''
        INSERT INTO balances_cache(customer_id, currency_code, balance_minor, tx_count, last_tx_at, computed_at)
        SELECT customer_id, currency_code,
          SUM(CASE type
            WHEN 'debit' THEN amount_minor WHEN 'adjust_up' THEN amount_minor WHEN 'opening' THEN amount_minor
            WHEN 'credit' THEN -amount_minor WHEN 'adjust_down' THEN -amount_minor END),
          COUNT(*), MAX(occurred_at), ?
        FROM transactions
        WHERE reversed_by_id IS NULL AND reverses_id IS NULL
        GROUP BY customer_id, currency_code
      ''', [now]);
    });
  }

  /// Compares cache with computed balances. Returns list of mismatches (empty = OK).
  Future<List<String>> verifyIntegrity() async {
    final problems = <String>[];
    final cached = await _db.query('balances_cache');
    for (final c in cached) {
      final cur = Currency.byCode(c['currency_code'] as String);
      final live = await balance(c['customer_id'] as String, cur);
      if (live.balance.minor != (c['balance_minor'] as int)) {
        problems.add(
            'customer=${c['customer_id']} ${cur.code}: cache=${c['balance_minor']} live=${live.balance.minor}');
      }
    }
    // Every reversal must point at an existing tx that points back.
    final dangling = await _db.rawQuery('''
      SELECT r.id FROM transactions r
      LEFT JOIN transactions o ON o.id = r.reverses_id
      WHERE r.reverses_id IS NOT NULL AND (o.id IS NULL OR o.reversed_by_id != r.id)
    ''');
    for (final d in dangling) {
      problems.add('dangling reversal ${d['id']}');
    }
    return problems;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<bool> _isCurrencyActive(String code) async {
    final r = await _db.query('currencies',
        columns: ['is_active'], where: 'code = ?', whereArgs: [code]);
    return r.isNotEmpty && (r.first['is_active'] as int) == 1;
  }

  Future<DateTime?> _lockedBefore() async {
    final r = await _db.query('settings',
        where: 'key = ?', whereArgs: ['locked_before']);
    if (r.isEmpty) return null;
    final v = jsonDecode(r.first['value_json'] as String);
    if (v == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(v as int, isUtc: true);
  }

  Future<Map<String, Object?>?> _customer(String id) async {
    final r = await _db.query('customers', where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? null : r.first;
  }

  Future<int> _nextSeq() async {
    final r = await _db.rawQuery(
        'SELECT COALESCE(MAX(local_seq),0)+1 AS n FROM transactions WHERE device_id = ?',
        [deviceId]);
    return (r.first['n'] as int?) ?? 1;
  }

  Future<void> _refreshCache(String customerId, Currency currency) async {
    final b = await balance(customerId, currency);
    await _db.insert(
      'balances_cache',
      {
        'customer_id': customerId,
        'currency_code': currency.code,
        'balance_minor': b.balance.minor,
        'tx_count': b.txCount,
        'last_tx_at': b.lastTxAt?.millisecondsSinceEpoch,
        'computed_at': _now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _audit(DatabaseExecutor txn, String entity, String entityId,
      String action, String actorId, Object? before, Object? after, DateTime at) {
    return txn.insert('audit_log', {
      'id': _uuid.v4(),
      'entity': entity,
      'entity_id': entityId,
      'action': action,
      'actor_id': actorId,
      'at': at.millisecondsSinceEpoch,
      'before_json': before == null ? null : jsonEncode(before),
      'after_json': after == null ? null : jsonEncode(after),
      'device_id': deviceId,
    });
  }

  /// Import a transaction row coming from another device (R6 idempotent).
  /// Returns true if inserted, false if it already existed.
  Future<bool> importRow(Map<String, Object?> row) async {
    final n = await _db.insert('transactions', row,
        conflictAlgorithm: ConflictAlgorithm.ignore);
    if (n != 0) {
      await _refreshCache(row['customer_id'] as String,
          Currency.byCode(row['currency_code'] as String));
      return true;
    }
    return false;
  }
}
