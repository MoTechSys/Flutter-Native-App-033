/// Currency definitions. See docs/04_LEDGER_RULES.md §4 (pre-defined currencies).
///
/// `minorUnits` is the number of decimal digits stored (R2):
/// YER has none (1 rial = 1 minor unit); SAR/USD have 2.
class Currency {
  final String code;
  final String nameAr;

  /// First word of the Arabic name ("ريال", "دولار") for compact display.
  String get shortName => nameAr.split(' ').first;
  final String symbol;
  final int minorUnits;

  const Currency({
    required this.code,
    required this.nameAr,
    required this.symbol,
    required this.minorUnits,
  }) : assert(minorUnits == 0 || minorUnits == 2);

  /// 10^minorUnits — multiplier between major and minor units.
  int get scale => minorUnits == 0 ? 1 : 100;

  static const yer = Currency(
      code: 'YER', nameAr: 'ريال يمني', symbol: 'ر.ي', minorUnits: 0);
  static const yerOld = Currency(
      code: 'YER_OLD',
      nameAr: 'ريال يمني (قديم)',
      symbol: 'ر.ي ق',
      minorUnits: 0);
  static const sar = Currency(
      code: 'SAR', nameAr: 'ريال سعودي', symbol: 'ر.س', minorUnits: 2);
  static const usd = Currency(
      code: 'USD', nameAr: 'دولار أمريكي', symbol: r'$', minorUnits: 2);

  static const all = [yer, yerOld, sar, usd];

  static Currency byCode(String code) => all.firstWhere(
        (c) => c.code == code,
        orElse: () => throw ArgumentError('Unknown currency: $code'),
      );

  static Currency? tryByCode(String code) {
    for (final c in all) {
      if (c.code == code) return c;
    }
    return null;
  }

  @override
  bool operator ==(Object other) => other is Currency && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => code;
}
