// ============================================================
// كِتابي - عناصر واجهة مشتركة
// ============================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_theme.dart';
import '../../models/models.dart';

final _money = NumberFormat('#,##0.##', 'en');
String fmtPrice(double v) => '${_money.format(v)} ر.س';
String fmtDate(DateTime d) => DateFormat('yyyy/MM/dd – HH:mm').format(d);

/// غلاف كتاب: صورة من Assets مع احتياط ملوّن بالعنوان
class BookCover extends StatelessWidget {
  final Book book;
  final double width;
  final double? height;
  final double radius;
  final bool hero;
  const BookCover({
    super.key,
    required this.book,
    this.width = 110,
    this.height,
    this.radius = 10,
    this.hero = true,
  });

  @override
  Widget build(BuildContext context) {
    final h = height ?? width * 1.45;
    final img = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: h,
        child: Image.asset(
          book.cover,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _Fallback(book: book),
        ),
      ),
    );
    final framed = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 6)),
        ],
      ),
      child: img,
    );
    return hero ? Hero(tag: 'cover-${book.id}', child: framed) : framed;
  }
}

class _Fallback extends StatelessWidget {
  final Book book;
  const _Fallback({required this.book});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(book.coverColor), Color(book.coverColor).withValues(alpha: 0.6)],
      ),
    ),
    alignment: Alignment.center,
    child: Text(
      book.title,
      textAlign: TextAlign.center,
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: AppText.serif,
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    ),
  );
}

/// نجوم التقييم
class RatingStars extends StatelessWidget {
  final double value;
  final double size;
  final bool showNumber;
  const RatingStars({super.key, required this.value, this.size = 14, this.showNumber = true});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 1; i <= 5; i++)
        Icon(
          value >= i ? Icons.star_rounded : (value >= i - 0.5 ? Icons.star_half_rounded : Icons.star_outline_rounded),
          size: size,
          color: Palette.gold,
        ),
      if (showNumber) ...[
        const SizedBox(width: 4),
        Text(value.toStringAsFixed(1), style: TextStyle(fontSize: size * 0.85, color: Palette.ivoryDim)),
      ],
    ],
  );
}

/// بطاقة سعر مع خصم اختياري
class PriceTag extends StatelessWidget {
  final Book book;
  final double size;
  const PriceTag({super.key, required this.book, this.size = 14});
  @override
  Widget build(BuildContext context) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 6,
    children: [
      Text(
        fmtPrice(book.price),
        style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: Palette.gold),
      ),
      if (book.hasDiscount)
        Text(
          fmtPrice(book.oldPrice!),
          style: TextStyle(
            fontSize: size * 0.8,
            color: Palette.ivoryDim,
            decoration: TextDecoration.lineThrough,
            decorationColor: Palette.ivoryDim,
          ),
        ),
    ],
  );
}

/// شارة خصم ذهبية
class DiscountRibbon extends StatelessWidget {
  final int percent;
  const DiscountRibbon({super.key, required this.percent});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Palette.gold,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      'خصم $percent%',
      style: const TextStyle(color: Palette.night, fontSize: 11, fontWeight: FontWeight.w800),
    ),
  );
}

/// عنوان قسم مع زر "الكل"
class SectionTitle extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SectionTitle({super.key, required this.title, this.actionLabel, this.onAction});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        Container(width: 3, height: 18, decoration: BoxDecoration(color: Palette.gold, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
        if (onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel ?? 'عرض الكل', style: const TextStyle(fontSize: 13)),
          ),
      ],
    ),
  );
}

/// حالة فارغة
class EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  const EmptyView({super.key, required this.icon, required this.title, this.subtitle, this.action});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Palette.gold.withValues(alpha: 0.1),
              border: Border.all(color: Palette.gold.withValues(alpha: 0.35)),
            ),
            child: Icon(icon, size: 38, color: Palette.gold),
          ),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, textAlign: TextAlign.center, style: const TextStyle(color: Palette.ivoryDim, height: 1.5)),
          ],
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    ),
  );
}

/// SnackBar موحّد
void notify(BuildContext context, String msg, {bool error = false, IconData? icon}) {
  ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: error ? Palette.danger : Palette.walnutLight,
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            Icon(icon ?? (error ? Icons.error_outline : Icons.check_circle_outline), color: Palette.ivory),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: const TextStyle(color: Palette.ivory))),
          ],
        ),
      ),
    );
}

/// حوار تأكيد
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String okLabel = 'تأكيد',
  bool destructive = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(okLabel, style: TextStyle(color: destructive ? Palette.danger : Palette.gold)),
        ),
      ],
    ),
  );
  return r ?? false;
}

// ------------------------------------------------------------ Validators
String? vEmail(String? v) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return 'أدخل البريد الإلكتروني';
  if (!RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$').hasMatch(s)) return 'صيغة البريد غير صحيحة (name@mail.com)';
  return null;
}

String? vPassword(String? v) {
  final s = v ?? '';
  if (s.isEmpty) return 'أدخل كلمة المرور';
  if (s.length < 6) return 'كلمة المرور 6 أحرف على الأقل';
  return null;
}

String? vName(String? v) {
  final s = (v ?? '').trim();
  if (s.length < 3) return 'الاسم 3 أحرف على الأقل';
  return null;
}

String? vPhone(String? v) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return null; // اختياري
  if (!RegExp(r'^\+?\d{9,15}$').hasMatch(s)) return 'رقم الجوال غير صحيح';
  return null;
}
