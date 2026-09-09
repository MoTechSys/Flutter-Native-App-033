import 'currency.dart';
import 'money.dart';

/// Number formatting for money. Western digits by default; optional
/// Arabic-Indic digits (docs/03_DESIGN.md §3).
class MoneyFormat {
  static const _arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

  /// "1,234,567" / "-500" / "123.45" (for 2-decimal currencies).
  static String amount(Money m, {bool arabicDigits = false}) {
    final neg = m.minor < 0;
    final abs = m.minor.abs();
    final c = m.currency;
    String whole;
    String frac = '';
    if (c.minorUnits == 0) {
      whole = abs.toString();
    } else {
      whole = (abs ~/ c.scale).toString();
      frac = (abs % c.scale).toString().padLeft(c.minorUnits, '0');
    }
    final grouped = _group(whole);
    var s = frac.isEmpty ? grouped : '$grouped.$frac';
    if (neg) s = '−$s'; // U+2212 minus, unambiguous in RTL
    return arabicDigits ? toArabicDigits(s) : s;
  }

  /// "1,234 ر.ي"
  static String withSymbol(Money m, {bool arabicDigits = false}) =>
      '${amount(m, arabicDigits: arabicDigits)} ${m.currency.symbol}';

  static String _group(String digits) {
    final b = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) b.write(',');
      b.write(digits[i]);
    }
    return b.toString();
  }

  static String toArabicDigits(String s) {
    final b = StringBuffer();
    for (final ch in s.split('')) {
      final d = int.tryParse(ch);
      b.write(d == null ? ch : _arabicDigits[d]);
    }
    return b.toString();
  }

  /// Parse user-typed digits (western or Arabic-Indic) into Money.
  static Money parse(String text, Currency c) {
    var t = text;
    for (var i = 0; i < 10; i++) {
      t = t.replaceAll(_arabicDigits[i], i.toString());
    }
    return Money.parseMajor(t, c);
  }
}
