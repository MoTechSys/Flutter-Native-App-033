import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_routes.dart';
import '../../core/money/arabic_words.dart';
import '../../core/money/money.dart';
import '../../core/money/money_format.dart';
import '../../data/app_services.dart';
import '../../data/repositories/overdue_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/session/session_provider.dart';
import '../../shared/l10n/ar_strings.dart';
import '../../shared/services/reminder_service.dart';
import '../../shared/services/speech_service.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/utils/date_labels.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/customer_avatar.dart';
import '../../shared/widgets/filter_chips.dart';

/// Overdue (phase 2): aging buckets 30/60/90/90+, remind all, promise to pay.
class OverdueScreen extends StatefulWidget {
  const OverdueScreen({super.key});

  @override
  State<OverdueScreen> createState() => _OverdueScreenState();
}

class _OverdueScreenState extends State<OverdueScreen> {
  List<OverdueItem> _all = const [];
  AgingBucket? _bucket; // null = all
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = context.read<AppServices>();
    final days = context.read<SettingsRepository>().overdueDays;
    final items = await OverdueRepository(s.db).list(overdueDays: days);
    if (!mounted) return;
    setState(() {
      _all = items;
      _loading = false;
    });
  }

  List<OverdueItem> get _shown =>
      _bucket == null ? _all : _all.where((x) => x.bucket == _bucket).toList();

  Money? get _total {
    if (_all.isEmpty) return null;
    var m = Money.zero(_all.first.balance.currency);
    for (final x in _shown) {
      m = m + x.balance;
    }
    return m;
  }

  Future<void> _remind(OverdueItem it, bool whatsapp) async {
    final s = context.read<AppServices>();
    final session = context.read<SessionProvider>();
    final st = context.read<SettingsRepository>();
    final svc = ReminderService(s.db, template: st.get<String>(SettingsRepository.kReminderTemplate));
    final by = session.user?.id ?? '';
    final shop = session.shop?.name ?? S.appName;
    final ok = whatsapp
        ? await svc.sendWhatsApp(customer: it.customer, balance: it.balance, shopName: shop, byUserId: by)
        : await svc.sendSms(customer: it.customer, balance: it.balance, shopName: shop, byUserId: by);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(it.customer.phoneE164 == null ? S.noPhone : 'تعذّر فتح التطبيق'),
          backgroundColor: AppColors.debt));
    }
    _load();
  }

  /// "ذكّر الكل": walks through customers with a phone, one WhatsApp at a time
  /// (WhatsApp has no bulk API; user confirms each). Logs each send.
  Future<void> _remindAll() async {
    final withPhone = _shown.where((x) => x.customer.phoneE164 != null).toList();
    if (withPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا أرقام هواتف للمتأخرين')));
      return;
    }
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تذكير الكل'),
        content: Text('سيُفتح واتساب ${withPhone.length} مرة، مرة لكل زبون. أكمل الإرسال ثم عُد للتطبيق.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text(S.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ابدأ')),
        ],
      ),
    );
    if (go != true) return;
    for (final it in withPhone) {
      if (!mounted) return;
      final next = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(it.customer.name),
          content: Text('${MoneyFormat.withName(it.balance)} — متأخر ${it.daysOverdue} يوماً'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تخطّي')),
            FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.chat_rounded),
                label: const Text('واتساب')),
          ],
        ),
      );
      if (next == true) await _remind(it, true);
    }
  }

  Future<void> _promise(OverdueItem it) async {
    final now = DateTime.now();
    final repo = OverdueRepository(context.read<AppServices>().db);
    final d = await showDatePicker(
      context: context,
      initialDate: it.promiseDate?.toLocal() ?? now.add(const Duration(days: 3)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
      helpText: 'وعد بالدفع — ${it.customer.name}',
    );
    if (d == null) return;
    await repo.setPromise(it.customer.id, DateTime.utc(d.year, d.month, d.day));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final speech = context.read<SpeechService>();
    final counts = <AgingBucket, int>{};
    for (final x in _all) {
      counts[x.bucket] = (counts[x.bucket] ?? 0) + 1;
    }
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text(S.overdue),
        actions: [
          IconButton(
            iconSize: 28,
            tooltip: S.listen,
            onPressed: () {
              final t = _total;
              speech.speak(_all.isEmpty
                  ? 'لا يوجد متأخرون'
                  : '${_all.length} متأخرون، مجموع ديونهم ${t == null ? '' : ArabicWords.money(t)}');
            },
            icon: const Icon(Icons.volume_up_rounded),
          ),
        ],
      ),
      floatingActionButton: _shown.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _remindAll,
              icon: const Icon(Icons.campaign_rounded, size: 28),
              label: const Text('ذكّر الكل', style: TextStyle(fontSize: 17)),
            ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: FilterChipsRow<AgingBucket?>(
                      value: _bucket,
                      items: [
                        (null, '${S.all} (${_all.length})', null),
                        (AgingBucket.d30, '30+ (${counts[AgingBucket.d30] ?? 0})', AppColors.accent),
                        (AgingBucket.d60, '60+ (${counts[AgingBucket.d60] ?? 0})', const Color(0xFFD9772A)),
                        (AgingBucket.d90, '90+ (${counts[AgingBucket.d90] ?? 0})', AppColors.debt),
                        (AgingBucket.d90plus, '180+ (${counts[AgingBucket.d90plus] ?? 0})', const Color(0xFF6B0F0F)),
                      ],
                      onChanged: (b) => setState(() => _bucket = b),
                    ),
                  ),
                  if (_total != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                            color: AppColors.debtContainer, borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppColors.debt),
                            const SizedBox(width: 10),
                            Text('${_shown.length} زبون — ',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            Text(MoneyFormat.withName(_total!),
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.debt)),
                          ],
                        ),
                      ),
                    ),
                  Expanded(
                    child: _shown.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.check_circle_outline_rounded, size: 80, color: AppColors.payment),
                                SizedBox(height: 12),
                                Text('لا متأخرون — ممتاز',
                                    style: TextStyle(fontSize: 18, color: AppColors.textSecondary)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                            itemCount: _shown.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) => _Row(
                              item: _shown[i],
                              onOpen: () async {
                                await Navigator.pushNamed(context, AppRoutes.customerDetail,
                                    arguments: _shown[i].customer.id);
                                _load();
                              },
                              onWhatsApp: () => _remind(_shown[i], true),
                              onSms: () => _remind(_shown[i], false),
                              onPromise: () => _promise(_shown[i]),
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final OverdueItem item;
  final VoidCallback onOpen, onWhatsApp, onSms, onPromise;
  const _Row({required this.item, required this.onOpen, required this.onWhatsApp, required this.onSms, required this.onPromise});

  Color get _bucketColor => switch (item.bucket) {
        AgingBucket.d30 => AppColors.accent,
        AgingBucket.d60 => const Color(0xFFD9772A),
        AgingBucket.d90 => AppColors.debt,
        AgingBucket.d90plus => const Color(0xFF6B0F0F),
      };

  @override
  Widget build(BuildContext context) {
    final c = item.customer;
    final hasPhone = c.phoneE164 != null;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            children: [
              Row(
                children: [
                  CustomerAvatar(name: c.name, photoPath: c.photoPath, size: 52, borderColor: _bucketColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                              decoration: BoxDecoration(color: _bucketColor, borderRadius: BorderRadius.circular(8)),
                              child: Text('${item.daysOverdue} يوم',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.lastPaymentAt == null
                                    ? 'لم يدفع شيئاً'
                                    : 'آخر دفعة ${DateLabels.ago(item.lastPaymentAt)}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(MoneyFormat.amount(item.balance),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.debt)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (item.promiseDate != null)
                    Expanded(
                      child: Row(
                        children: [
                          Icon(item.promiseBroken ? Icons.event_busy_rounded : Icons.event_available_rounded,
                              size: 16, color: item.promiseBroken ? AppColors.debt : AppColors.payment),
                          const SizedBox(width: 4),
                          Text(
                            'وعد: ${DateLabels.short(item.promiseDate!)}${item.promiseBroken ? ' (تجاوز)' : ''}',
                            style: TextStyle(fontSize: 12, color: item.promiseBroken ? AppColors.debt : AppColors.payment,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    )
                  else if (item.lastReminderAt != null)
                    Expanded(
                      child: Text('ذُكِّر ${DateLabels.ago(item.lastReminderAt)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    )
                  else
                    const Spacer(),
                  _Small(icon: Icons.event_rounded, label: 'وعد', onTap: onPromise),
                  _Small(icon: Icons.sms_rounded, label: S.sms, onTap: hasPhone ? onSms : null),
                  _Small(icon: Icons.chat_rounded, label: S.whatsapp, onTap: hasPhone ? onWhatsApp : null, filled: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Small extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;
  const _Small({required this.icon, required this.label, this.onTap, this.filled = false});
  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : AppColors.primary;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 6),
      child: Opacity(
        opacity: onTap == null ? 0.35 : 1,
        child: Material(
          color: filled ? AppColors.primary : AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 4),
                  Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
