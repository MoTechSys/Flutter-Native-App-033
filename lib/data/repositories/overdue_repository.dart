import 'package:sqflite_common/sqlite_api.dart';
import 'package:uuid/uuid.dart';

import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../models/customer.dart';

/// Aging bucket by days since last payment (or since first debt if none).
enum AgingBucket { d30, d60, d90, d90plus }

class OverdueItem {
  final Customer customer;
  final Money balance;
  final DateTime? lastPaymentAt;
  final DateTime firstDebtAt;
  final int daysOverdue;
  final AgingBucket bucket;
  final DateTime? promiseDate;
  final DateTime? lastReminderAt;
  const OverdueItem({
    required this.customer,
    required this.balance,
    required this.lastPaymentAt,
    required this.firstDebtAt,
    required this.daysOverdue,
    required this.bucket,
    required this.promiseDate,
    required this.lastReminderAt,
  });

  bool get promiseBroken => promiseDate != null && promiseDate!.isBefore(DateTime.now().toUtc());
}

/// Overdue analysis in the primary currency (phase 2). Read-only over the ledger.
/// Promises are kept in `settings` under `promise.<customerId>` (no schema change).
class OverdueRepository {
  final Database _db;
  OverdueRepository(this._db);
  static const _uuid = Uuid();

  Future<List<OverdueItem>> list({required int overdueDays, Currency? currency}) async {
    final cur = currency ?? await _primary();
    final now = DateTime.now().toUtc();
    final cutoff = now.subtract(Duration(days: overdueDays)).millisecondsSinceEpoch;

    final rows = await _db.rawQuery('''
      SELECT c.*, b.balance_minor,
        (SELECT MAX(occurred_at) FROM transactions t WHERE t.customer_id=c.id AND t.type='credit'
           AND t.currency_code=? AND t.reversed_by_id IS NULL AND t.reverses_id IS NULL) AS last_pay,
        (SELECT MIN(occurred_at) FROM transactions t WHERE t.customer_id=c.id AND t.type IN ('debit','opening','adjust_up')
           AND t.currency_code=? AND t.reversed_by_id IS NULL AND t.reverses_id IS NULL) AS first_debt,
        (SELECT MAX(sent_at) FROM reminders r WHERE r.customer_id=c.id) AS last_rem
      FROM balances_cache b JOIN customers c ON c.id=b.customer_id
      WHERE b.currency_code=? AND b.balance_minor>0 AND c.is_archived=0
    ''', [cur.code, cur.code, cur.code]);

    final promises = await _db.query('settings', where: "key LIKE 'promise.%'");
    final promiseMap = <String, int>{};
    for (final p in promises) {
      final v = p['value_json'] as String;
      final n = int.tryParse(v);
      if (n != null) promiseMap[(p['key'] as String).substring(8)] = n;
    }

    final out = <OverdueItem>[];
    for (final r in rows) {
      final lastPay = r['last_pay'] as int?;
      final firstDebt = (r['first_debt'] as int?) ?? now.millisecondsSinceEpoch;
      final since = lastPay ?? firstDebt;
      if (since >= cutoff) continue; // paid recently → not overdue
      final days = now.difference(DateTime.fromMillisecondsSinceEpoch(since, isUtc: true)).inDays;
      final c = Customer.fromRow(r);
      final pm = promiseMap[c.id];
      out.add(OverdueItem(
        customer: c,
        balance: Money(r['balance_minor'] as int, cur),
        lastPaymentAt: lastPay == null ? null : DateTime.fromMillisecondsSinceEpoch(lastPay, isUtc: true),
        firstDebtAt: DateTime.fromMillisecondsSinceEpoch(firstDebt, isUtc: true),
        daysOverdue: days,
        bucket: bucketFor(days),
        promiseDate: pm == null ? null : DateTime.fromMillisecondsSinceEpoch(pm, isUtc: true),
        lastReminderAt: r['last_rem'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(r['last_rem'] as int, isUtc: true),
      ));
    }
    out.sort((a, b) => b.daysOverdue.compareTo(a.daysOverdue));
    return out;
  }

  static AgingBucket bucketFor(int days) {
    if (days < 60) return AgingBucket.d30;
    if (days < 90) return AgingBucket.d60;
    if (days < 180) return AgingBucket.d90;
    return AgingBucket.d90plus;
  }

  Future<void> setPromise(String customerId, DateTime? date) async {
    final key = 'promise.$customerId';
    if (date == null) {
      await _db.delete('settings', where: 'key = ?', whereArgs: [key]);
    } else {
      await _db.insert('settings',
          {'key': key, 'value_json': '${date.toUtc().millisecondsSinceEpoch}'},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> logReminder(String customerId, String channel, Money balance, String by) =>
      _db.insert('reminders', {
        'id': _uuid.v4(),
        'customer_id': customerId,
        'channel': channel,
        'balance_snap_minor': balance.minor,
        'currency_code': balance.currency.code,
        'sent_at': DateTime.now().toUtc().millisecondsSinceEpoch,
        'sent_by': by,
      });

  Future<Currency> _primary() async {
    final r = await _db.query('currencies', where: 'is_primary = 1', limit: 1);
    return r.isEmpty ? Currency.yer : Currency.byCode(r.first['code'] as String);
  }
}
