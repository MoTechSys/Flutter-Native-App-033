// ============================================================
// كِتابي - الملف الشخصي (بديل القائمة الجانبية)
// يُفتح من صورة المستخدم في رأس الرئيسية.
// يحوي: تعديل البيانات، طلباتي، تغيير كلمة المرور، حول التطبيق،
//        تسجيل الخروج، حذف الحساب.
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../state/session.dart';
import '../../state/store_state.dart';
import '../orders/orders_page.dart';
import '../shared/widgets.dart';
import 'about_page.dart';
import 'change_password_page.dart';
import 'edit_profile_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _signOut(BuildContext context) async {
    final ok = await confirm(context, title: 'تسجيل الخروج', message: 'هل تريد تسجيل الخروج من حسابك؟', okLabel: 'خروج');
    if (!ok || !context.mounted) return;
    context.read<CartState>().unbind();
    context.read<FavoritesState>().unbind();
    await context.read<Session>().signOut();
    // البوابة (_Gate) في main.dart ستُبدّل الشاشة إلى تسجيل الدخول تلقائيًا
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final ok = await confirm(
      context,
      title: 'حذف الحساب',
      message: 'سيتم حذف حسابك وسلتك ومفضلتك وطلباتك نهائيًا من قاعدة البيانات. هل أنت متأكد؟',
      okLabel: 'حذف نهائي',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    context.read<CartState>().unbind();
    context.read<FavoritesState>().unbind();
    await context.read<Session>().deleteAccount();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<Session>().user;
    if (user == null) return const Scaffold(body: SizedBox.shrink());
    final initials = user.name.trim().isEmpty ? '؟' : user.name.trim().characters.first;

    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // ---------------- بطاقة المستخدم
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: [Palette.gold, Palette.goldDim]),
                        boxShadow: [BoxShadow(color: Palette.gold.withValues(alpha: .3), blurRadius: 14)],
                      ),
                      alignment: Alignment.center,
                      child: Text(initials, style: AppText.serifStyle(26, color: Palette.night)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name, style: AppText.serifStyle(19, color: Palette.ivory), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 3),
                          Text(user.email, style: const TextStyle(color: Palette.ivoryDim, fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                          if ((user.city ?? '').isNotEmpty || (user.phone ?? '').isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              [if ((user.city ?? '').isNotEmpty) user.city!, if ((user.phone ?? '').isNotEmpty) user.phone!].join(' • '),
                              style: const TextStyle(color: Palette.ivoryDim, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'تعديل البيانات',
                      icon: const Icon(Icons.edit_outlined, color: Palette.gold),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfilePage())),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ---------------- الطلبات والحساب
            const SectionTitle(title: 'النشاط'),
            const SizedBox(height: 6),
            Card(
              child: Column(
                children: [
                  _Item(
                    icon: Icons.receipt_long_outlined,
                    title: 'طلباتي',
                    subtitle: 'تتبّع حالة الطلبات وتفاصيلها',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersPage())),
                  ),
                  const Divider(height: 1, color: Palette.line),
                  _Item(
                    icon: Icons.lock_outline,
                    title: 'تغيير كلمة المرور',
                    subtitle: 'يتطلب كلمة المرور الحالية',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordPage())),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            const SectionTitle(title: 'عام'),
            const SizedBox(height: 6),
            Card(
              child: Column(
                children: [
                  _Item(
                    icon: Icons.info_outline,
                    title: 'حول التطبيق',
                    subtitle: 'الإصدار، المطوّر، والمزايا',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutPage())),
                  ),
                  const Divider(height: 1, color: Palette.line),
                  _Item(
                    icon: Icons.logout,
                    title: 'تسجيل الخروج',
                    subtitle: 'تبقى بياناتك محفوظة على الجهاز',
                    onTap: () => _signOut(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            const SectionTitle(title: 'منطقة الخطر'),
            const SizedBox(height: 6),
            Card(
              child: _Item(
                icon: Icons.delete_forever_outlined,
                title: 'حذف الحساب',
                subtitle: 'حذف نهائي لكل بياناتك من قاعدة البيانات',
                color: Palette.danger,
                onTap: () => _deleteAccount(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  final Color? color;
  const _Item({required this.icon, required this.title, required this.subtitle, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Palette.gold;
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: c.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: c, size: 21),
      ),
      title: Text(title, style: TextStyle(color: color ?? Palette.ivory, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(color: Palette.ivoryDim, fontSize: 12)),
      trailing: const Icon(Icons.chevron_left, color: Palette.ivoryDim),
    );
  }
}
