import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app_routes.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/money/money_format.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/session/session_provider.dart';
import '../../shared/l10n/ar_strings.dart';
import '../../shared/services/speech_service.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/utils/date_labels.dart';
import '../../shared/widgets/app_back_button.dart';

/// Settings (phase 2). Grouped, each row ≥ 56dp, every change spoken briefly.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<SettingsRepository>();
    final session = context.watch<SessionProvider>();
    final speech = context.read<SpeechService>();
    final isOwner = session.isOwner;

    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(), title: const Text(S.settings)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            _Section('المحل', [
              _Tile(
                icon: Icons.storefront_rounded,
                title: session.shop?.name ?? '',
                subtitle: 'اسم المحل، العنوان، الهاتف (يظهر في المستندات)',
                onTap: isOwner ? () => _editShop(context) : null,
              ),
              if (isOwner)
                _Tile(
                  icon: Icons.savings_rounded,
                  title: S.currencies,
                  subtitle: 'تفعيل العملات وأسعار الصرف',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.currencies),
                ),
            ]),
            _Section('الكلمات (D11)', [
              _Tile(
                icon: Icons.arrow_downward_rounded,
                iconColor: AppColors.debt,
                title: st.labelTook,
                subtitle: 'كلمة زر "أخذ" — غيّرها حسب لهجة المنطقة',
                onTap: () => _editText(context, 'كلمة الأخذ', SettingsRepository.kLabelTook, st),
              ),
              _Tile(
                icon: Icons.arrow_upward_rounded,
                iconColor: AppColors.payment,
                title: st.labelPaid,
                subtitle: 'كلمة زر "دفع"',
                onTap: () => _editText(context, 'كلمة الدفع', SettingsRepository.kLabelPaid, st),
              ),
            ]),
            _Section('الصوت', [
              _Switch(
                icon: Icons.volume_up_rounded,
                title: 'القراءة الصوتية',
                subtitle: 'يقرأ كل عملية بعد حفظها',
                value: st.voiceEnabled,
                onChanged: (v) async {
                  await st.set(SettingsRepository.kVoiceEnabled, v);
                  speech.enabled = v;
                  if (v) speech.speak('تم تشغيل الصوت');
                },
              ),
              _Tile(
                icon: Icons.speed_rounded,
                title: 'سرعة الكلام',
                subtitle: _rateLabel(st.get<double>(SettingsRepository.kVoiceRate)),
                trailing: SizedBox(
                  width: 150,
                  child: Slider(
                    value: st.get<double>(SettingsRepository.kVoiceRate),
                    min: 0.3,
                    max: 0.7,
                    divisions: 4,
                    onChanged: (v) => st.set(SettingsRepository.kVoiceRate, v, notify: true),
                    onChangeEnd: (v) {
                      speech.setRate(v);
                      speech.speak('هذه سرعة الكلام');
                    },
                  ),
                ),
              ),
              _Tile(
                icon: Icons.headset_mic_rounded,
                title: S.voiceHelp,
                subtitle: 'شرح صوتي لكل شاشة',
                onTap: () => Navigator.pushNamed(context, AppRoutes.voiceHelp),
              ),
            ]),
            _Section('المظهر', [
              _Switch(
                icon: Icons.dark_mode_rounded,
                title: 'الوضع الداكن',
                subtitle: 'أفضل ليلاً؛ الفاتح أوضح تحت الشمس',
                value: st.darkMode,
                onChanged: (v) => st.set(SettingsRepository.kDarkMode, v),
              ),
              _Switch(
                icon: Icons.translate_rounded,
                title: 'أرقام عربية (١٢٣)',
                subtitle: 'بدل 123',
                value: st.arabicDigits,
                onChanged: (v) => st.set(SettingsRepository.kArabicDigits, v),
              ),
              _Tile(
                icon: Icons.format_size_rounded,
                title: 'حجم الخط',
                subtitle: '${(st.fontScale * 100).round()}%',
                trailing: SizedBox(
                  width: 150,
                  child: Slider(
                    value: st.fontScale,
                    min: 0.9,
                    max: 1.3,
                    divisions: 4,
                    onChanged: (v) => st.set(SettingsRepository.kFontScale, v),
                  ),
                ),
              ),
            ]),
            if (isOwner)
              _Section('الديون', [
                _Tile(
                  icon: Icons.schedule_rounded,
                  title: 'يُعدّ متأخراً بعد',
                  subtitle: '${st.overdueDays} يوماً بلا دفعة',
                  onTap: () => _pickDays(context, st),
                ),
                _Tile(
                  icon: Icons.notifications_active_rounded,
                  title: 'تنبيه المالك عند دفعة كبيرة',
                  subtitle: _bigPaymentLabel(st),
                  onTap: () => _editBigPayment(context, st),
                ),
                _Tile(
                  icon: Icons.lock_clock_rounded,
                  title: 'قفل الفترة',
                  subtitle: st.lockedBefore == null
                      ? 'لا قفل — العامل يستطيع تسجيل حركات بتاريخ قديم'
                      : 'مقفل قبل ${DateLabels.short(st.lockedBefore!)} — لا تسجيل قديم إلا للمالك بسبب',
                  onTap: () => _pickLock(context, st),
                ),
                _Tile(
                  icon: Icons.chat_rounded,
                  title: 'نص التذكير (واتساب/رسالة)',
                  subtitle: 'المتغيرات: {name} {shop} {amount} {words}',
                  onTap: () => _editTemplate(context, st),
                ),
              ]),
            _Section('الأمان', [
              _Tile(
                icon: Icons.pin_rounded,
                title: session.user?.hasPin == true ? 'تغيير رمز الدخول' : 'إضافة رمز دخول',
                subtitle: '4 أرقام لحسابك',
                onTap: () => _changePin(context, session),
              ),
              if (isOwner)
                _Tile(
                  icon: Icons.badge_rounded,
                  title: S.workers,
                  subtitle: 'الحسابات والصلاحيات',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.workers),
                ),
              if (isOwner)
                _Tile(
                  icon: Icons.key_rounded,
                  title: S.activation,
                  subtitle: st.get<String?>(SettingsRepository.kActivationCode) == null
                      ? 'النسخة التجريبية'
                      : 'مفعّل',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.activation),
                ),
            ]),
            _Section('البيانات', [
              if (isOwner)
                _Tile(
                  icon: Icons.cloud_rounded,
                  title: S.backup,
                  subtitle: 'نسخة محلية / Google Drive / تصدير',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.backup),
                ),
              _Tile(
                icon: Icons.info_outline_rounded,
                title: 'عن التطبيق',
                subtitle: 'سِجِل ${S.version} 0.2.0 — دفتر ديون للمحلات',
              ),
            ]),
          ],
        ),
      ),
    );
  }

  static String _rateLabel(double r) {
    if (r <= 0.35) return 'بطيئة جداً';
    if (r <= 0.45) return 'بطيئة (مناسبة للتعلّم)';
    if (r <= 0.55) return 'عادية';
    return 'سريعة';
  }

  static String _bigPaymentLabel(SettingsRepository st) {
    final m = st.get<int>(SettingsRepository.kBigPaymentAlertMinor);
    if (m <= 0) return 'معطّل';
    return 'أكثر من ${MoneyFormat.withName(Money(m, Currency.yer))}';
  }

  static Future<void> _editText(
      BuildContext context, String title, String key, SettingsRepository st) async {
    final ctrl = TextEditingController(text: st.get<String>(key));
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 14,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text(S.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text(S.save)),
        ],
      ),
    );
    if (v != null && v.trim().isNotEmpty) await st.set(key, v.trim());
  }

  static Future<void> _editTemplate(BuildContext context, SettingsRepository st) async {
    final ctrl = TextEditingController(text: st.get<String>(SettingsRepository.kReminderTemplate));
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('نص التذكير'),
        content: TextField(controller: ctrl, autofocus: true, maxLines: 6, style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, SettingsRepository.defaults[SettingsRepository.kReminderTemplate] as String),
              child: const Text('الافتراضي')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text(S.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text(S.save)),
        ],
      ),
    );
    if (v != null && v.trim().isNotEmpty) await st.set(SettingsRepository.kReminderTemplate, v);
  }

  static Future<void> _pickDays(BuildContext context, SettingsRepository st) async {
    final v = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final d in [7, 15, 30, 45, 60, 90])
              ListTile(
                minTileHeight: 56,
                title: Text('$d يوماً', style: const TextStyle(fontSize: 18)),
                trailing: st.overdueDays == d ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                onTap: () => Navigator.pop(ctx, d),
              ),
          ],
        ),
      ),
    );
    if (v != null) await st.set(SettingsRepository.kOverdueDays, v);
  }

  static Future<void> _editBigPayment(BuildContext context, SettingsRepository st) async {
    final cur = st.get<int>(SettingsRepository.kBigPaymentAlertMinor);
    final ctrl = TextEditingController(text: cur <= 0 ? '' : '$cur');
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تنبيه عند دفعة كبيرة'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(suffixText: 'ريال', hintText: '0 = معطّل'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text(S.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text(S.save)),
        ],
      ),
    );
    if (v != null) await st.set(SettingsRepository.kBigPaymentAlertMinor, int.tryParse(v) ?? 0);
  }

  static Future<void> _pickLock(BuildContext context, SettingsRepository st) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              minTileHeight: 60,
              leading: const Icon(Icons.lock_rounded, color: AppColors.primary),
              title: const Text('قفل حتى نهاية الشهر الماضي', style: TextStyle(fontSize: 17)),
              onTap: () => Navigator.pop(ctx, 'month'),
            ),
            ListTile(
              minTileHeight: 60,
              leading: const Icon(Icons.event_rounded, color: AppColors.primary),
              title: const Text('اختيار تاريخ', style: TextStyle(fontSize: 17)),
              onTap: () => Navigator.pop(ctx, 'pick'),
            ),
            ListTile(
              minTileHeight: 60,
              leading: const Icon(Icons.lock_open_rounded, color: AppColors.debt),
              title: const Text('إزالة القفل', style: TextStyle(fontSize: 17)),
              onTap: () => Navigator.pop(ctx, 'none'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (choice == 'none') {
      await st.set(SettingsRepository.kLockedBefore, null);
      return;
    }
    DateTime? d;
    final now = DateTime.now();
    if (choice == 'month') {
      d = DateTime(now.year, now.month, 1);
    } else if (context.mounted) {
      d = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: DateTime(now.year - 5),
        lastDate: now,
        helpText: 'لا تسجيل قبل هذا التاريخ',
      );
    }
    if (d != null) {
      await st.set(SettingsRepository.kLockedBefore, DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch);
    }
  }

  static Future<void> _changePin(BuildContext context, SessionProvider session) async {
    final ctrl = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('رمز الدخول'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 28, letterSpacing: 10, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(hintText: '••••', counterText: ''),
        ),
        actions: [
          if (session.user?.hasPin == true)
            TextButton(onPressed: () => Navigator.pop(ctx, ''), child: const Text('إزالة الرمز')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text(S.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text(S.save)),
        ],
      ),
    );
    if (v == null) return;
    if (v.isEmpty) {
      await session.setPin(session.user!.id, null);
    } else if (v.length == 4) {
      await session.setPin(session.user!.id, v);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرمز 4 أرقام')));
    }
  }

  static Future<void> _editShop(BuildContext context) async {
    final session = context.read<SessionProvider>();
    final s = session.shop!;
    final name = TextEditingController(text: s.name);
    final addr = TextEditingController(text: s.address ?? '');
    final phone = TextEditingController(text: s.phone ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('بيانات المحل'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: S.shopName)),
            TextField(controller: addr, decoration: const InputDecoration(labelText: 'العنوان')),
            TextField(controller: phone, keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: S.phone)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text(S.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text(S.save)),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      await session.updateShop(name: name.text, address: addr.text, phone: phone.text);
    }
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section(this.title, this.children);
  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
            child: Text(title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          ),
          Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 64),
                children[i],
              ],
            ]),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _Tile({required this.icon, this.iconColor, required this.title, this.subtitle, this.trailing, this.onTap});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 60,
      leading: Icon(icon, size: 28, color: iconColor ?? Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      subtitle: subtitle == null ? null : Text(subtitle!, style: const TextStyle(fontSize: 12.5)),
      trailing: trailing ?? (onTap == null ? null : const Icon(Icons.chevron_left_rounded)),
      onTap: onTap,
    );
  }
}

class _Switch extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Switch({required this.icon, required this.title, this.subtitle, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      subtitle: subtitle == null ? null : Text(subtitle!, style: const TextStyle(fontSize: 12.5)),
      value: value,
      onChanged: onChanged,
    );
  }
}
