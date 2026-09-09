import 'package:sqflite_common/sqlite_api.dart';
import 'package:uuid/uuid.dart';

import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../models/customer.dart';

/// Customer list sorting (docs/03 §6.6).
enum CustomerSort { recentActivity, alphabetical, largestDebt }

/// Customer list filter (docs/03 §6.6).
enum CustomerFilter { all, owing, overdue, settled }

/// A customer together with its cached balance in the primary currency
/// and any other non-zero balances (R4: per currency, never mixed).
class CustomerWithBalance {
  final Customer customer;
  final Money primaryBalance;
  final Map<Currency, Money> otherBalances;
  final bool isOverdue;
  const CustomerWithBalance({
    required this.customer,
    required this.primaryBalance,
    required this.otherBalances,
    required this.isOverdue,
  });
}

/// CRUD for `customers` (docs/05 §4). Never touches `transactions`
/// (only LedgerService may — R1).
class CustomerRepository {
  final Database _db;
  final String shopId;
  final String deviceId;
  CustomerRepository(this._db, {required this.shopId, required this.deviceId});

  static const _uuid = Uuid();

  Future<Currency> primaryCurrency() async {
    final r = await _db.query('currencies', where: 'is_primary = 1', limit: 1);
    return r.isEmpty ? Currency.yer : Currency.byCode(r.first['code'] as String);
  }

  Future<Customer?> getById(String id) async {
    final r = await _db.query('customers', where: 'id = ?', whereArgs: [id], limit: 1);
    return r.isEmpty ? null : Customer.fromRow(r.first);
  }

  Future<int> countActive() async {
    final r = await _db.rawQuery(
        'SELECT COUNT(*) AS c FROM customers WHERE shop_id = ? AND is_archived = 0', [shopId]);
    return (r.first['c'] as int?) ?? 0;
  }

  /// Full list with balances. Filtering/sorting is done in memory after a
  /// single simple query (small data set per shop; avoids index dependencies).
  Future<List<CustomerWithBalance>> list({
    CustomerFilter filter = CustomerFilter.all,
    CustomerSort sort = CustomerSort.recentActivity,
    String query = '',
    bool includeArchived = false,
    int overdueDays = 30,
  }) async {
    final primary = await primaryCurrency();
    final rows = await _db.query('customers',
        where: includeArchived ? 'shop_id = ?' : 'shop_id = ? AND is_archived = 0',
        whereArgs: [shopId]);
    final balances = await _db.query('balances_cache');
    final byCustomer = <String, Map<Currency, Money>>{};
    for (final b in balances) {
      final cur = Currency.byCode(b['currency_code'] as String);
      byCustomer
          .putIfAbsent(b['customer_id'] as String, () => {})[cur] =
          Money(b['balance_minor'] as int, cur);
    }

    final cutoff = DateTime.now().toUtc().subtract(Duration(days: overdueDays));
    final recentCredit = await _db.rawQuery('''
      SELECT DISTINCT customer_id FROM transactions
      WHERE type = 'credit' AND occurred_at >= ? AND reversed_by_id IS NULL AND reverses_id IS NULL
    ''', [cutoff.millisecondsSinceEpoch]);
    final paidRecently = recentCredit.map((r) => r['customer_id'] as String).toSet();

    final q = query.trim();
    final out = <CustomerWithBalance>[];
    for (final r in rows) {
      final c = Customer.fromRow(r);
      if (q.isNotEmpty && !c.name.contains(q) && !(c.phone?.contains(q) ?? false)) continue;
      final bal = byCustomer[c.id] ?? const {};
      final prim = bal[primary] ?? Money.zero(primary);
      final others = Map<Currency, Money>.from(bal)
        ..remove(primary)
        ..removeWhere((_, m) => m.isZero);
      final overdue = prim.isPositive && !paidRecently.contains(c.id);
      final cw = CustomerWithBalance(
          customer: c, primaryBalance: prim, otherBalances: others, isOverdue: overdue);
      switch (filter) {
        case CustomerFilter.all:
          out.add(cw);
        case CustomerFilter.owing:
          if (prim.isPositive || others.values.any((m) => m.isPositive)) out.add(cw);
        case CustomerFilter.overdue:
          if (overdue) out.add(cw);
        case CustomerFilter.settled:
          if (prim.isZero && others.isEmpty) out.add(cw);
      }
    }

    switch (sort) {
      case CustomerSort.recentActivity:
        out.sort((a, b) {
          final x = a.customer.lastActivityAt?.millisecondsSinceEpoch ?? 0;
          final y = b.customer.lastActivityAt?.millisecondsSinceEpoch ?? 0;
          final c = y.compareTo(x);
          return c != 0 ? c : a.customer.name.compareTo(b.customer.name);
        });
      case CustomerSort.alphabetical:
        out.sort((a, b) => a.customer.name.compareTo(b.customer.name));
      case CustomerSort.largestDebt:
        out.sort((a, b) => b.primaryBalance.minor.compareTo(a.primaryBalance.minor));
    }
    return out;
  }

  /// Most recently active customers (for the "الأخيرون" row in step 1).
  Future<List<Customer>> recent({int limit = 8}) async {
    final rows = await _db.query('customers',
        where: 'shop_id = ? AND is_archived = 0 AND last_activity_at IS NOT NULL',
        whereArgs: [shopId],
        orderBy: 'last_activity_at DESC',
        limit: limit);
    return rows.map(Customer.fromRow).toList();
  }

  Future<Customer> add({
    required String name,
    String? phone,
    String? photoPath,
    String? voiceNamePath,
    String? note,
    required String byUserId,
  }) async {
    final n = name.trim();
    if (n.isEmpty) throw ArgumentError('name required');
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final id = _uuid.v4();
    await _db.insert('customers', {
      'id': id,
      'shop_id': shopId,
      'name': n,
      'phone': _cleanPhone(phone),
      'photo_path': photoPath,
      'voice_name_path': voiceNamePath,
      'note': _nullIfBlank(note),
      'is_archived': 0,
      'created_at': now,
      'updated_at': now,
      'updated_by': byUserId,
    });
    await _audit('customer', id, 'create', byUserId, now);
    return (await getById(id))!;
  }

  Future<void> update(
    String id, {
    String? name,
    String? phone,
    String? photoPath,
    String? voiceNamePath,
    String? note,
    int? creditLimitMinor,
    String? creditLimitCurrency,
    required String byUserId,
  }) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final values = <String, Object?>{'updated_at': now, 'updated_by': byUserId};
    if (name != null) values['name'] = name.trim();
    if (phone != null) values['phone'] = _cleanPhone(phone);
    if (photoPath != null) values['photo_path'] = photoPath;
    if (voiceNamePath != null) values['voice_name_path'] = voiceNamePath;
    if (note != null) values['note'] = _nullIfBlank(note);
    if (creditLimitMinor != null) values['credit_limit_minor'] = creditLimitMinor;
    if (creditLimitCurrency != null) values['credit_limit_currency'] = creditLimitCurrency;
    await _db.update('customers', values, where: 'id = ?', whereArgs: [id]);
    await _audit('customer', id, 'update', byUserId, now);
  }

  Future<void> setArchived(String id, bool archived, {required String byUserId}) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _db.update('customers',
        {'is_archived': archived ? 1 : 0, 'updated_at': now, 'updated_by': byUserId},
        where: 'id = ?', whereArgs: [id]);
    await _audit('customer', id, archived ? 'archive' : 'unarchive', byUserId, now);
  }

  Future<void> _audit(String entity, String id, String action, String by, int at) =>
      _db.insert('audit_log', {
        'id': _uuid.v4(),
        'entity': entity,
        'entity_id': id,
        'action': action,
        'actor_id': by,
        'at': at,
        'device_id': deviceId,
      });

  static String? _cleanPhone(String? p) {
    if (p == null) return null;
    final s = p.replaceAll(RegExp(r'[^0-9+]'), '');
    return s.isEmpty ? null : s;
  }

  static String? _nullIfBlank(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
}
