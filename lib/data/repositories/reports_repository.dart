import 'package:sqflite_common/sqlite_api.dart';

import '../../core/money/currency.dart';
import '../../core/money/money.dart';

enum ReportPeriod { today, week, month, year }

class PeriodSummary {
  final DateTime from, to;
  final Money took, paid, adjustNet;
  final int txCount, customersServed;
  const PeriodSummary({
    required this.from,
    required this.to,
    required this.took,
    required this.paid,
    required this.adjustNet,
    required this.txCount,
    required this.customersServed,
  });

  /// Net change in what people owe during the period.
  Money get netChange => took - paid + adjustNet;
}

class DayPoint {
  final DateTime day;
  final Money took, paid;
  const DayPoint(this.day, this.took, this.paid);
}

class TopDebtor {
  final String customerId, name;
  final String? photoPath;
  final Money balance;
  const TopDebtor({required this.customerId, required this.name, this.photoPath, required this.balance});
}

class WorkerStat {
  final String userId, name;
  final int txCount;
  final Money took, paid;
  final int reversals;
  const WorkerStat({required this.userId, required this.name, required this.txCount, required this.took, required this.paid, required this.reversals});
}

/// Read-only aggregates over live transactions in one currency (R4).
/// All sums are integer minor units done by SQLite (R2).
class ReportsRepository {
  final Database _db;
  ReportsRepository(this._db);

  static const _live = 'reversed_by_id IS NULL AND reverses_id IS NULL';

  static (DateTime, DateTime) range(ReportPeriod p, {DateTime? now}) {
    final n = (now ?? DateTime.now()).toLocal();
    final today = DateTime(n.year, n.month, n.day);
    switch (p) {
      case ReportPeriod.today:
        return (today, today.add(const Duration(days: 1)));
      case ReportPeriod.week:
        // Saturday-start week (Yemen).
        final back = (n.weekday - DateTime.saturday) % 7;
        final start = today.subtract(Duration(days: back));
        return (start, start.add(const Duration(days: 7)));
      case ReportPeriod.month:
        return (DateTime(n.year, n.month, 1), DateTime(n.year, n.month + 1, 1));
      case ReportPeriod.year:
        return (DateTime(n.year, 1, 1), DateTime(n.year + 1, 1, 1));
    }
  }

  Future<PeriodSummary> summary(Currency cur, DateTime from, DateTime to) async {
    final f = from.toUtc().millisecondsSinceEpoch, t = to.toUtc().millisecondsSinceEpoch;
    final rows = await _db.rawQuery('''
      SELECT type, COALESCE(SUM(amount_minor),0) AS s, COUNT(*) AS n
      FROM transactions WHERE currency_code=? AND occurred_at>=? AND occurred_at<? AND $_live
      GROUP BY type
    ''', [cur.code, f, t]);
    var took = 0, paid = 0, adj = 0, n = 0;
    for (final r in rows) {
      final s = (r['s'] as int?) ?? 0;
      n += (r['n'] as int?) ?? 0;
      switch (r['type']) {
        case 'debit':
        case 'opening':
          took += s;
        case 'credit':
          paid += s;
        case 'adjust_up':
          adj += s;
        case 'adjust_down':
          adj -= s;
      }
    }
    final cust = await _db.rawQuery('''
      SELECT COUNT(DISTINCT customer_id) AS c FROM transactions
      WHERE currency_code=? AND occurred_at>=? AND occurred_at<? AND $_live
    ''', [cur.code, f, t]);
    return PeriodSummary(
      from: from,
      to: to,
      took: Money(took, cur),
      paid: Money(paid, cur),
      adjustNet: Money(adj, cur),
      txCount: n,
      customersServed: (cust.first['c'] as int?) ?? 0,
    );
  }

  /// Daily series for charts (fills missing days with zero).
  Future<List<DayPoint>> daily(Currency cur, DateTime from, DateTime to) async {
    final f = from.toUtc().millisecondsSinceEpoch, t = to.toUtc().millisecondsSinceEpoch;
    final rows = await _db.rawQuery('''
      SELECT occurred_at, type, amount_minor FROM transactions
      WHERE currency_code=? AND occurred_at>=? AND occurred_at<? AND $_live
    ''', [cur.code, f, t]);
    final took = <int, int>{}, paid = <int, int>{};
    for (final r in rows) {
      final d = DateTime.fromMillisecondsSinceEpoch(r['occurred_at'] as int, isUtc: true).toLocal();
      final key = DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
      final a = r['amount_minor'] as int;
      switch (r['type']) {
        case 'debit':
        case 'opening':
        case 'adjust_up':
          took[key] = (took[key] ?? 0) + a;
        case 'credit':
        case 'adjust_down':
          paid[key] = (paid[key] ?? 0) + a;
      }
    }
    final out = <DayPoint>[];
    for (var d = DateTime(from.year, from.month, from.day); d.isBefore(to); d = d.add(const Duration(days: 1))) {
      final k = d.millisecondsSinceEpoch;
      out.add(DayPoint(d, Money(took[k] ?? 0, cur), Money(paid[k] ?? 0, cur)));
    }
    return out;
  }

  Future<List<TopDebtor>> topDebtors(Currency cur, {int limit = 10}) async {
    final rows = await _db.rawQuery('''
      SELECT c.id, c.name, c.photo_path, b.balance_minor FROM balances_cache b
      JOIN customers c ON c.id=b.customer_id
      WHERE b.currency_code=? AND b.balance_minor>0 AND c.is_archived=0
      ORDER BY b.balance_minor DESC LIMIT ?
    ''', [cur.code, limit]);
    return rows
        .map((r) => TopDebtor(
              customerId: r['id'] as String,
              name: r['name'] as String,
              photoPath: r['photo_path'] as String?,
              balance: Money(r['balance_minor'] as int, cur),
            ))
        .toList();
  }

  Future<List<WorkerStat>> workers(Currency cur, DateTime from, DateTime to) async {
    final f = from.toUtc().millisecondsSinceEpoch, t = to.toUtc().millisecondsSinceEpoch;
    final rows = await _db.rawQuery('''
      SELECT recorded_by AS uid, MAX(user_name_snap) AS name, COUNT(*) AS n,
        COALESCE(SUM(CASE WHEN type IN ('debit','opening','adjust_up') THEN amount_minor END),0) AS took,
        COALESCE(SUM(CASE WHEN type IN ('credit','adjust_down') THEN amount_minor END),0) AS paid,
        COALESCE(SUM(CASE WHEN reversed_by_id IS NOT NULL THEN 1 ELSE 0 END),0) AS rev
      FROM transactions
      WHERE currency_code=? AND occurred_at>=? AND occurred_at<? AND reverses_id IS NULL
      GROUP BY recorded_by ORDER BY n DESC
    ''', [cur.code, f, t]);
    return rows
        .map((r) => WorkerStat(
              userId: r['uid'] as String,
              name: r['name'] as String,
              txCount: r['n'] as int,
              took: Money(r['took'] as int, cur),
              paid: Money(r['paid'] as int, cur),
              reversals: r['rev'] as int,
            ))
        .toList();
  }
}
