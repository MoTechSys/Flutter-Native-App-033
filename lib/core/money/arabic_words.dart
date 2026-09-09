import 'currency.dart';
import 'money.dart';

/// Converts integers to Arabic words for TTS and receipts
/// ("ثلاثة آلاف وخمسمائة"). Covers 0 .. 999,999,999,999.
class ArabicWords {
  static const _ones = [
    'صفر', 'واحد', 'اثنان', 'ثلاثة', 'أربعة', 'خمسة', 'ستة', 'سبعة', 'ثمانية',
    'تسعة', 'عشرة', 'أحد عشر', 'اثنا عشر', 'ثلاثة عشر', 'أربعة عشر',
    'خمسة عشر', 'ستة عشر', 'سبعة عشر', 'ثمانية عشر', 'تسعة عشر'
  ];
  static const _tens = [
    '', '', 'عشرون', 'ثلاثون', 'أربعون', 'خمسون', 'ستون', 'سبعون', 'ثمانون',
    'تسعون'
  ];
  static const _hundreds = [
    '', 'مائة', 'مائتان', 'ثلاثمائة', 'أربعمائة', 'خمسمائة', 'ستمائة',
    'سبعمائة', 'ثمانمائة', 'تسعمائة'
  ];

  static String integer(int n) {
    if (n < 0) return 'ناقص ${integer(-n)}';
    if (n < 20) return _ones[n];
    if (n < 100) {
      final t = _tens[n ~/ 10];
      final o = n % 10;
      return o == 0 ? t : '${_ones[o]} و$t';
    }
    if (n < 1000) {
      final h = _hundreds[n ~/ 100];
      final rest = n % 100;
      return rest == 0 ? h : '$h و${integer(rest)}';
    }
    if (n < 1000000) {
      final th = n ~/ 1000;
      final rest = n % 1000;
      final thWords = _scaled(th, 'ألف', 'ألفان', 'آلاف', 'ألفاً');
      return rest == 0 ? thWords : '$thWords و${integer(rest)}';
    }
    if (n < 1000000000) {
      final m = n ~/ 1000000;
      final rest = n % 1000000;
      final mWords = _scaled(m, 'مليون', 'مليونان', 'ملايين', 'مليوناً');
      return rest == 0 ? mWords : '$mWords و${integer(rest)}';
    }
    final b = n ~/ 1000000000;
    final rest = n % 1000000000;
    final bWords = _scaled(b, 'مليار', 'ملياران', 'مليارات', 'ملياراً');
    return rest == 0 ? bWords : '$bWords و${integer(rest)}';
  }

  /// Arabic number agreement: 1→singular, 2→dual, 3-10→plural, 11+→accusative singular.
  static String _scaled(
      int count, String singular, String dual, String plural, String acc) {
    if (count == 1) return singular;
    if (count == 2) return dual;
    if (count >= 3 && count <= 10) return '${_ones[count]} $plural';
    final last = count % 100;
    if (last >= 3 && last <= 10) return '${integer(count)} $plural';
    return '${integer(count)} $acc';
  }

  /// "ثلاثة آلاف وخمسمائة ريال يمني" / "اثنا عشر ريال سعودي وخمسون هللة".
  static String money(Money m) {
    final c = m.currency;
    final abs = m.minor.abs();
    final major = abs ~/ c.scale;
    final minor = abs % c.scale;
    final sb = StringBuffer();
    if (m.minor < 0) sb.write('ناقص ');
    sb.write('${integer(major)} ${c.nameAr}');
    if (c.minorUnits == 2 && minor > 0) {
      sb.write(' و${integer(minor)} ${_minorName(c)}');
    }
    return sb.toString();
  }

  static String _minorName(Currency c) {
    switch (c.code) {
      case 'SAR':
        return 'هللة';
      case 'USD':
        return 'سنت';
      default:
        return 'فلس';
    }
  }
}
