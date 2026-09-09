import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/activation/activation.dart';
import '../../data/app_services.dart';
import '../../data/repositories/settings_repository.dart';
import '../../shared/l10n/ar_strings.dart';
import '../../shared/services/speech_service.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/utils/date_labels.dart';
import '../../shared/widgets/app_back_button.dart';

/// Activation (phase 2): shows device id (to send to the seller via WhatsApp),
/// accepts the offline code, shows trial/plan state. Rate-limited attempts.
class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final _code = TextEditingController();
  String? _error;
  bool _busy = false;

  static const _kAttempts = 'activation.attempts';
  static const _kAttemptsResetMs = 'activation.attempts_reset_ms';

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final st = context.read<SettingsRepository>();
    final services = context.read<AppServices>();
    final speech = context.read<SpeechService>();
    final now = DateTime.now().toUtc();

    // Rate limit: 5 attempts / hour.
    final resetMs = st.get<int?>(_kAttemptsResetMs);
    var attempts = st.get<int?>(_kAttempts) ?? 0;
    if (resetMs == null || now.millisecondsSinceEpoch > resetMs) {
      attempts = 0;
      await st.set(_kAttemptsResetMs, now.add(const Duration(hours: 1)).millisecondsSinceEpoch, notify: false);
    }
    if (attempts >= 5) {
      setState(() => _error = 'محاولات كثيرة — حاول بعد ساعة');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final info = Activation.verify(_code.text, services.deviceId);
    if (info == null || !info.isValidAt(now)) {
      await st.set(_kAttempts, attempts + 1, notify: false);
      setState(() {
        _busy = false;
        _error = info == null ? 'الكود غير صحيح لهذا الجهاز' : 'الكود منتهي الصلاحية';
      });
      speech.speak('الكود غير صحيح');
      return;
    }
    await st.set(SettingsRepository.kActivationCode, info.code, notify: false);
    await st.set(SettingsRepository.kActivationExpires, info.expires?.millisecondsSinceEpoch);
    await st.set(_kAttempts, 0, notify: false);
    speech.speak('تم التفعيل، ${info.planAr}');
    if (mounted) {
      setState(() => _busy = false);
      _code.clear();
    }
  }

  Future<void> _deactivate() async {
    final st = context.read<SettingsRepository>();
    await st.set(SettingsRepository.kActivationCode, null, notify: false);
    await st.set(SettingsRepository.kActivationExpires, null);
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<SettingsRepository>();
    final services = context.read<AppServices>();
    final code = st.get<String?>(SettingsRepository.kActivationCode);
    final expMs = st.get<int?>(SettingsRepository.kActivationExpires);
    final expires = expMs == null ? null : DateTime.fromMillisecondsSinceEpoch(expMs, isUtc: true);
    final now = DateTime.now().toUtc();
    final activated = code != null && (expires == null || now.isBefore(expires));
    final installed = DateTime.fromMillisecondsSinceEpoch(
        st.get<int?>(SettingsRepository.kInstalledAt) ?? now.millisecondsSinceEpoch, isUtc: true);
    final trialLeft = TrialPolicy.daysLeft(installed, now);

    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(), title: const Text(S.activation)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Status card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: activated ? AppColors.paymentContainer : AppColors.accentContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Icon(activated ? Icons.verified_rounded : Icons.hourglass_bottom_rounded,
                      size: 56, color: activated ? AppColors.payment : AppColors.accent),
                  const SizedBox(height: 8),
                  Text(
                    activated
                        ? 'مفعّل'
                        : (trialLeft > 0 ? 'تجريبي — باقي $trialLeft يوماً' : 'انتهت الفترة التجريبية'),
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: activated ? AppColors.payment : AppColors.accent),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    activated
                        ? (expires == null ? 'مدى الحياة' : 'حتى ${DateLabels.short(expires)}')
                        : 'بعد انتهاء التجربة: قراءة فقط + علامة على المستندات. بياناتك لا تُحذف أبداً.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                  ),
                  if (activated) ...[
                    const SizedBox(height: 8),
                    TextButton(onPressed: _deactivate, child: const Text('إزالة التفعيل')),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Device id
            const Text('1) أرسل رقم جهازك للبائع',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: services.deviceId));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('تم نسخ رقم الجهاز')));
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(services.deviceId,
                            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                            textDirection: TextDirection.ltr),
                      ),
                      const Icon(Icons.copy_rounded, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('2) أدخل كود التفعيل', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            TextField(
              controller: _code,
              textDirection: TextDirection.ltr,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 1.5),
              decoration: InputDecoration(
                hintText: 'SJL-XXXX-XXXX-XXXXXX',
                hintTextDirection: TextDirection.ltr,
                errorText: _error,
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 60,
              child: FilledButton.icon(
                onPressed: _busy || _code.text.trim().isEmpty ? null : _activate,
                icon: const Icon(Icons.key_rounded, size: 26),
                label: const Text('تفعيل', style: TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'الدفع عبر جوالي / ون كاش / كريمي للبائع المعتمد، ويرسل لك الكود على واتساب. '
              'الكود مرتبط بجهازك ولا يعمل على جهاز آخر.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
