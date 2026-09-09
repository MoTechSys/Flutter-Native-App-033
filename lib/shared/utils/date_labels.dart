import 'package:intl/intl.dart';

/// Arabic date/time labels shared by lists (docs/03 §6.3: اليوم/أمس/التاريخ).
class DateLabels {
  DateLabels._();

  static final _dayFmt = DateFormat('EEEE d MMMM', 'ar');
  static final _shortFmt = DateFormat('d/M/yyyy', 'ar');
  static final _timeFmt = DateFormat('h:mm a', 'ar');

  static DateTime _local(DateTime d) => d.toLocal();

  static bool sameDay(DateTime a, DateTime b) {
    final x = _local(a), y = _local(b);
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }

  /// "اليوم — الثلاثاء 9 سبتمبر" / "أمس" / "الثلاثاء 9 سبتمبر"
  static String sectionHeader(DateTime d, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final l = _local(d);
    if (sameDay(l, n)) return 'اليوم — ${_dayFmt.format(l)}';
    if (sameDay(l, n.subtract(const Duration(days: 1)))) return 'أمس';
    return _dayFmt.format(l);
  }

  static String time(DateTime d) =>
      _timeFmt.format(_local(d)).replaceAll('AM', 'ص').replaceAll('PM', 'م');

  static String short(DateTime d) => _shortFmt.format(_local(d));

  static String full(DateTime d) => '${short(d)} ${time(d)}';

  /// "قبل 3 أيام" style relative text for customer cards.
  static String ago(DateTime? d, {DateTime? now}) {
    if (d == null) return 'لا تعامل بعد';
    final n = now ?? DateTime.now();
    final diff = n.difference(_local(d));
    if (diff.inDays == 0) return 'اليوم';
    if (diff.inDays == 1) return 'أمس';
    if (diff.inDays == 2) return 'قبل يومين';
    if (diff.inDays <= 10) return 'قبل ${diff.inDays} أيام';
    if (diff.inDays < 30) return 'قبل ${diff.inDays} يوماً';
    final months = diff.inDays ~/ 30;
    if (months == 1) return 'قبل شهر';
    if (months == 2) return 'قبل شهرين';
    if (months <= 10) return 'قبل $months أشهر';
    return short(d);
  }
}
