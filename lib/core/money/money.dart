import 'currency.dart';

/// Thrown when combining two [Money] values of different currencies (R4).
class CurrencyMismatchError extends Error {
  final Currency a;
  final Currency b;
  CurrencyMismatchError(this.a, this.b);
  @override
  String toString() => 'CurrencyMismatchError: $a vs $b';
}

/// Immutable money value stored as integer minor units (R2).
///
/// Never use double for money. Arithmetic is only allowed between
/// the same currency; anything else throws [CurrencyMismatchError].
class Money implements Comparable<Money> {
  final int minor;
  final Currency currency;

  const Money(this.minor, this.currency);

  const Money.zero(this.currency) : minor = 0;

  /// Build from major units (e.g. 12.34 SAR -> 1234 minor). Input is a
  /// string to avoid double rounding issues when parsing user input.
  factory Money.parseMajor(String text, Currency currency) {
    final cleaned = text.replaceAll(',', '').replaceAll('٬', '').trim();
    if (cleaned.isEmpty) throw const FormatException('empty amount');
    final neg = cleaned.startsWith('-') || cleaned.startsWith('−');
    final body = neg ? cleaned.substring(1) : cleaned;
    final parts = body.split(RegExp('[.٫]'));
    if (parts.length > 2) throw FormatException('bad amount: $text');
    final whole = parts[0].isEmpty ? '0' : parts[0];
    if (!RegExp(r'^\d+$').hasMatch(whole)) {
      throw FormatException('bad amount: $text');
    }
    var frac = parts.length == 2 ? parts[1] : '';
    if (frac.isNotEmpty && !RegExp(r'^\d+$').hasMatch(frac)) {
      throw FormatException('bad amount: $text');
    }
    if (frac.length > currency.minorUnits) {
      throw FormatException(
          'too many decimals for ${currency.code}: $text');
    }
    frac = frac.padRight(currency.minorUnits, '0');
    final minor = int.parse(whole) * currency.scale +
        (frac.isEmpty ? 0 : int.parse(frac));
    return Money(neg ? -minor : minor, currency);
  }

  bool get isZero => minor == 0;
  bool get isPositive => minor > 0;
  bool get isNegative => minor < 0;

  Money get abs => Money(minor.abs(), currency);
  Money get negated => Money(-minor, currency);

  void _check(Money other) {
    if (other.currency != currency) {
      throw CurrencyMismatchError(currency, other.currency);
    }
  }

  Money operator +(Money other) {
    _check(other);
    return Money(minor + other.minor, currency);
  }

  Money operator -(Money other) {
    _check(other);
    return Money(minor - other.minor, currency);
  }

  bool operator >(Money other) {
    _check(other);
    return minor > other.minor;
  }

  bool operator <(Money other) {
    _check(other);
    return minor < other.minor;
  }

  bool operator >=(Money other) => !(this < other);
  bool operator <=(Money other) => !(this > other);

  @override
  int compareTo(Money other) {
    _check(other);
    return minor.compareTo(other.minor);
  }

  /// Convert using an exact fraction rate `num/den` (R2): result is rounded
  /// half-to-even to the target currency's minor unit. Display only.
  Money convert(Currency to, int rateNum, int rateDen) {
    if (rateDen == 0) throw ArgumentError('rateDen must not be 0');
    // value_major_from = minor / scale_from
    // value_major_to   = value_major_from * num/den
    // minor_to         = value_major_to * scale_to
    final numerator = BigInt.from(minor) * BigInt.from(rateNum) * BigInt.from(to.scale);
    final denominator = BigInt.from(currency.scale) * BigInt.from(rateDen);
    return Money(_divRoundHalfEven(numerator, denominator).toInt(), to);
  }

  static BigInt _divRoundHalfEven(BigInt a, BigInt b) {
    if (b.isNegative) {
      a = -a;
      b = -b;
    }
    final q = a ~/ b; // truncates toward zero
    final r = a - q * b; // same sign as a
    final twice = r.abs() * BigInt.two;
    final cmp = twice.compareTo(b);
    if (cmp < 0) return q;
    if (cmp > 0) return a.isNegative ? q - BigInt.one : q + BigInt.one;
    // exactly half → round to even
    if (q.isEven) return q;
    return a.isNegative ? q - BigInt.one : q + BigInt.one;
  }

  @override
  bool operator ==(Object other) =>
      other is Money && other.minor == minor && other.currency == currency;

  @override
  int get hashCode => Object.hash(minor, currency);

  @override
  String toString() => '$minor ${currency.code}';
}
