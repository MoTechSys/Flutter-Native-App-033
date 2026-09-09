import 'package:sqflite_common/sqlite_api.dart';

import '../../core/ledger/ledger_models.dart';
import '../../core/ledger/ledger_service.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';

/// Read-model for the home dashboard (docs/03 §6.1). Read-only.
class DashboardRepository {
  final Database _db;
  final LedgerService _ledger;
  DashboardRepository(this._db, this._ledger);

  Future<DashboardData> load({int overdueDays = 30}) async {
    final now = DateTime.now().toUtc();
    final startOfDay = DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch;

    final totals = await _ledger.totalOwedByCurrency();
    final primary = await _primaryCurrency();

    final todayRows = await _db.rawQuery('''
      SELECT type, SUM(amount_minor) AS s FROM transactions
      WHERE occurred_at >= ? AND currency_code = ? AND reversed_by_id IS NULL AND reverses_id IS NULL
      GROUP BY type
    ''', [startOfDay, primary.code]);
    var todayTook = 0, todayPaid = 0;
    for (final r in todayRows) {
      final s = (r['s'] as int?) ?? 0;
      if (r['type'] == 'debit') todayTook += s;
      if (r['type'] == 'credit') todayPaid += s;
    }

    // Overdue: positive balance and no credit within `overdueDays`.
    final cutoff = now.subtract(Duration(days: overdueDays)).millisecondsSinceEpoch;
    final overdueRows = await _db.rawQuery('''
      SELECT c.id, c.name, c.photo_path, b.balance_minor
      FROM balances_cache b JOIN customers c ON c.id = b.customer_id
      WHERE b.currency_code = ? AND b.balance_minor > 0 AND c.is_archived = 0
        AND NOT EXISTS (
          SELECT 1 FROM transactions t WHERE t.customer_id = c.id AND t.type='credit'
            AND t.occurred_at >= ? AND t.reversed_by_id IS NULL AND t.reverses_id IS NULL)
      ORDER BY b.balance_minor DESC
    ''', [primary.code, cutoff]);

    final recentTx = await _ledger.recent(limit: 15);
    final recent = <RecentItem>[];
    for (final tx in recentTx) {
      if (tx.isReversal || tx.isReversed) continue;
      final c = await _db.query('customers',
          columns: ['name', 'photo_path'], where: 'id=?', whereArgs: [tx.customerId]);
      recent.add(RecentItem(
        tx: tx,
        customerName: c.isEmpty ? tx.customerNameSnap : c.first['name'] as String,
        photoPath: c.isEmpty ? null : c.first['photo_path'] as String?,
      ));
    }

    return DashboardData(
      primaryCurrency: primary,
      totalsByCurrency: totals,
      todayTook: Money(todayTook, primary),
      todayPaid: Money(todayPaid, primary),
      overdue: overdueRows
          .map((r) => OverdueItem(
                customerId: r['id'] as String,
                name: r['name'] as String,
                photoPath: r['photo_path'] as String?,
                balance: Money(r['balance_minor'] as int, primary),
              ))
          .toList(),
      recent: recent,
    );
  }

  Future<Currency> _primaryCurrency() async {
    final r = await _db.query('currencies', where: 'is_primary = 1', limit: 1);
    return r.isEmpty ? Currency.yer : Currency.byCode(r.first['code'] as String);
  }
}

class DashboardData {
  final Currency primaryCurrency;
  final Map<Currency, Money> totalsByCurrency;
  final Money todayTook;
  final Money todayPaid;
  final List<OverdueItem> overdue;
  final List<RecentItem> recent;
  const DashboardData({
    required this.primaryCurrency,
    required this.totalsByCurrency,
    required this.todayTook,
    required this.todayPaid,
    required this.overdue,
    required this.recent,
  });

  Money get primaryTotal =>
      totalsByCurrency[primaryCurrency] ?? Money.zero(primaryCurrency);
}

class OverdueItem {
  final String customerId;
  final String name;
  final String? photoPath;
  final Money balance;
  const OverdueItem(
      {required this.customerId, required this.name, this.photoPath, required this.balance});
}

class RecentItem {
  final LedgerTx tx;
  final String customerName;
  final String? photoPath;
  const RecentItem({required this.tx, required this.customerName, this.photoPath});
}
