import 'package:sqflite_common/sqlite_api.dart';
import 'package:uuid/uuid.dart';

import '../../core/money/currency.dart';
import '../../core/money/money.dart';

/// A currency row with its activation state.
class CurrencyState {
  final Currency currency;
  final bool isActive;
  final bool isPrimary;
  final int sort;
  const CurrencyState(this.currency, {required this.isActive, required this.isPrimary, required this.sort});
}

/// Manual exchange rate: 1 [from] = rateNum/rateDen [to] (exact rational, R2).
class FxRate {
  final Currency from;
  final Currency to;
  final int rateNum;
  final int rateDen;
  final DateTime setAt;
  const FxRate({required this.from, required this.to, required this.rateNum, required this.rateDen, required this.setAt});

  /// Human value e.g. 1 USD = 530 YER → "530"
  double get value => rateNum / rateDen;
}

/// Currencies + manual FX rates (docs/06 phase 2; R4: rates are display-only —
/// balances are never converted for storage).
class CurrencyRepository {
  final Database _db;
  CurrencyRepository(this._db);
  static const _uuid = Uuid();

  Future<List<CurrencyState>> all() async {
    final rows = await _db.query('currencies', orderBy: 'is_primary DESC, sort');
    return rows
        .map((r) => CurrencyState(
              Currency.byCode(r['code'] as String),
              isActive: (r['is_active'] as int) == 1,
              isPrimary: (r['is_primary'] as int) == 1,
              sort: r['sort'] as int,
            ))
        .toList();
  }

  Future<List<Currency>> active() async =>
      (await all()).where((c) => c.isActive).map((c) => c.currency).toList();

  Future<Currency> primary() async {
    final r = await _db.query('currencies', where: 'is_primary = 1', limit: 1);
    return r.isEmpty ? Currency.yer : Currency.byCode(r.first['code'] as String);
  }

  /// The primary currency can never be deactivated.
  Future<void> setActive(String code, bool active) async {
    final p = await primary();
    if (!active && p.code == code) throw StateError('primary currency cannot be deactivated');
    await _db.update('currencies', {'is_active': active ? 1 : 0}, where: 'code = ?', whereArgs: [code]);
  }

  /// Setting primary also activates it.
  Future<void> setPrimary(String code) async {
    await _db.transaction((txn) async {
      await txn.update('currencies', {'is_primary': 0});
      await txn.update('currencies', {'is_primary': 1, 'is_active': 1}, where: 'code = ?', whereArgs: [code]);
    });
  }

  /// Store 1 [from] = [value] [to] as an exact fraction (up to 4 decimals).
  Future<void> setRate(Currency from, Currency to, String value, {String? byUserId}) async {
    final parsed = parseRate(value);
    if (parsed == null) throw ArgumentError('invalid rate');
    final (num_, den) = parsed;
    await _db.insert('fx_rates', {
      'id': _uuid.v4(),
      'from_code': from.code,
      'to_code': to.code,
      'rate_num': num_,
      'rate_den': den,
      'set_at': DateTime.now().toUtc().millisecondsSinceEpoch,
      'set_by': byUserId,
    });
  }

  /// "530" → (530,1); "0.0019" → (19,10000); "3.75" → (375,100). Null if invalid/zero.
  static (int, int)? parseRate(String text) {
    final t = text.trim().replaceAll('٬', '').replaceAll(',', '');
    final western = t.replaceAllMapped(RegExp('[٠-٩]'), (m) => (m[0]!.codeUnitAt(0) - 0x0660).toString());
    if (!RegExp(r'^\d{1,9}(\.\d{1,4})?$').hasMatch(western)) return null;
    final parts = western.split('.');
    final frac = parts.length > 1 ? parts[1] : '';
    final den = _pow10(frac.length);
    final numV = int.parse(parts[0]) * den + (frac.isEmpty ? 0 : int.parse(frac));
    if (numV == 0) return null;
    final g = _gcd(numV, den);
    return (numV ~/ g, den ~/ g);
  }

  /// Latest rate for the pair, or null.
  Future<FxRate?> latest(Currency from, Currency to) async {
    final r = await _db.query('fx_rates',
        where: 'from_code = ? AND to_code = ?', whereArgs: [from.code, to.code],
        orderBy: 'set_at DESC, rowid DESC', limit: 1);
    if (r.isEmpty) return null;
    final row = r.first;
    return FxRate(
      from: from,
      to: to,
      rateNum: row['rate_num'] as int,
      rateDen: row['rate_den'] as int,
      setAt: DateTime.fromMillisecondsSinceEpoch(row['set_at'] as int, isUtc: true),
    );
  }

  /// Approximate value of [m] in [to] using the latest rate (display only, "≈").
  Future<Money?> approx(Money m, Currency to) async {
    if (m.currency == to) return m;
    final r = await latest(m.currency, to);
    if (r != null) return m.convert(to, r.rateNum, r.rateDen);
    final inv = await latest(to, m.currency);
    if (inv != null) return m.convert(to, inv.rateDen, inv.rateNum);
    return null;
  }

  static int _pow10(int n) {
    var r = 1;
    for (var i = 0; i < n; i++) {
      r *= 10;
    }
    return r;
  }

  static int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);
}
