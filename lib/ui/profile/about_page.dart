// ============================================================
// كِتابي - حول التطبيق
// يعرض هوية التطبيق، معلومات الطالب، المزايا، والتقنيات
// (يستخدم Stack لتراكب الشعار على خلفية متدرجة)
// ============================================================

import 'package:flutter/material.dart';

import '../../app_theme.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const appVersion = '1.0.0';
  static const studentName = 'علي عبده يحيى';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حول التطبيق')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // ------------- غلاف بـ Stack
            SizedBox(
              height: 170,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [Palette.walnut, Palette.nightSoft],
                      ),
                      border: Border.all(color: Palette.gold.withValues(alpha: .35)),
                    ),
                  ),
                  Positioned(
                    left: -30,
                    top: -30,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Palette.gold.withValues(alpha: .08)),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset(
                            'assets/brand/logo.png',
                            width: 72,
                            height: 72,
                            errorBuilder: (_, _, _) => const Icon(Icons.auto_stories, size: 60, color: Palette.gold),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text('كِتابي', style: AppText.serifStyle(26, color: Palette.ivory)),
                        const Text('متجر كتب عربي — محاكاة', style: TextStyle(color: Palette.ivoryDim, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Palette.gold,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('v$appVersion', style: const TextStyle(color: Palette.night, fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            _Section(
              title: 'عن المشروع',
              child: const Text(
                'تطبيق متجر كتب (محاكاة) يتيح تصفح الكتب حسب التصنيفات، البحث والتصفية، '
                'إضافة الكتب إلى سلة المشتريات أو المفضلة، استعراض تفاصيل الكتاب مع التقييمات، '
                'وإتمام الطلب وتتبع حالته. جميع البيانات (المستخدمون، الكتب الحقيقية، السلة، المفضلة، الطلبات، التقييمات) '
                'تُخزَّن محليًا في قاعدة بيانات SQLite تُنشأ تلقائيًا عند أول تشغيل.',
                style: TextStyle(color: Palette.ivoryDim, height: 1.7, fontSize: 13.5),
              ),
            ),
            const SizedBox(height: 12),

            _Section(
              title: 'الطالب',
              child: const Row(
                children: [
                  CircleAvatar(backgroundColor: Palette.gold, child: Icon(Icons.school_outlined, color: Palette.night)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(studentName, style: TextStyle(color: Palette.ivory, fontWeight: FontWeight.w700, fontSize: 15)),
                        Text('مشروع مقرر تطوير تطبيقات الهاتف — Flutter', style: TextStyle(color: Palette.ivoryDim, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            _Section(
              title: 'المزايا',
              child: const Column(
                children: [
                  _Feature(Icons.grid_view_rounded, 'تصفح حسب 6 تصنيفات و24 كتابًا حقيقيًا'),
                  _Feature(Icons.search, 'بحث فوري مع تصفية بالسعر والتصنيف والترتيب'),
                  _Feature(Icons.shopping_bag_outlined, 'سلة مشتريات مع كوبونات خصم وإتمام الطلب'),
                  _Feature(Icons.favorite_border, 'مفضلة قابلة للمزامنة مع السلة'),
                  _Feature(Icons.rate_review_outlined, 'تقييمات ومراجعات (إضافة/تعديل/حذف)'),
                  _Feature(Icons.local_shipping_outlined, 'تتبع حالة الطلب وإلغاؤه'),
                  _Feature(Icons.lock_reset, 'استعادة كلمة المرور برمز OTP في 3 خطوات'),
                  _Feature(Icons.arrow_back, 'زر الرجوع يعود خطوة بخطوة داخل كل تبويب'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            _Section(
              title: 'التقنيات',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _Chip('Flutter 3.35'),
                  _Chip('Dart 3.9'),
                  _Chip('Material 3'),
                  _Chip('Provider'),
                  _Chip('sqflite (SQLite)'),
                  _Chip('shared_preferences'),
                  _Chip('Nested Navigator'),
                  _Chip('Hero Animations'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text('© 2025 كِتابي — جميع الحقوق محفوظة', style: TextStyle(color: Palette.ivoryDim, fontSize: 11.5)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.serifStyle(17, color: Palette.gold)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Feature(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Palette.gold),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: Palette.ivory, fontSize: 13.5))),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Palette.nightSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Palette.line),
      ),
      child: Text(label, style: const TextStyle(color: Palette.ivoryDim, fontSize: 12)),
    );
  }
}
