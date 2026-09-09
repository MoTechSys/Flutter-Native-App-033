import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_routes.dart';
import '../../core/ledger/ledger_models.dart';
import '../../core/ledger/tx_type.dart';
import '../../core/money/money.dart';
import '../../core/money/money_format.dart';
import '../../data/app_services.dart';
import '../../data/models/customer.dart';
import '../../data/repositories/transactions_repository.dart';
import '../../data/session/session_provider.dart';
import '../../shared/l10n/ar_strings.dart';
import '../../shared/services/reminder_service.dart';
import '../../shared/services/speech_service.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/customer_avatar.dart';
import '../../shared/widgets/tx_tile.dart';
import '../transactions/new_transaction_flow.dart';
import 'add_customer_screen.dart';

/// Customer page (docs/03 §6.5). One screen, no long scroll: header, big
/// balance, action row, last 5 transactions + "الكل".
class CustomerDetailScreen extends StatefulWidget {
  final String customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  Customer? _customer;
  List<CustomerBalance> _balances = const [];
  List<TxListItem> _recent = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = context.read<AppServices>();
    try {
      final c = await s.customers.getById(widget.customerId);
      if (c == null) throw StateError('customer not found');
      final b = await s.ledger.balancesAllCurrencies(c.id);
      final r = await s.transactions.page(customerId: c.id, limit: 5);
      if (!mounted) return;
      setState(() {
        _customer = c;
        _balances = b.where((x) => !x.balance.isZero || x.txCount > 0).toList();
        _recent = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _newTx(TxType type) async {
    final c = _customer!;
    final saved = await NewTransactionFlow.start(context, customerId: c.id, type: type);
    if (saved && mounted) _load();
  }

  Future<void> _remind(bool whatsapp) async {
    final c = _customer!;
    if (c.phoneE164 == null) {
      _snack(S.noPhone, error: true);
      return;
    }
    final s = context.read<AppServices>();
    final session = context.read<SessionProvider>();
    final bal = _balances.isEmpty ? Money.zero(await s.customers.primaryCurrency()) : _balances.first.balance;
    final svc = ReminderService(s.db);
    final by = session.user?.id ?? 'unknown';
    final shop = session.shop?.name ?? S.appName;
    final ok = whatsapp
        ? await svc.sendWhatsApp(customer: c, balance: bal, shopName: shop, byUserId: by)
        : await svc.sendSms(customer: c, balance: bal, shopName: shop, byUserId: by);
    if (!mounted) return;
    _snack(ok ? S.reminderSent : 'تعذّر فتح التطبيق', error: !ok);
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 16)),
      backgroundColor: error ? AppColors.debt : AppColors.primary,
    ));
  }

  Future<void> _menu(String v) async {
    final c = _customer!;
    final session = context.read<SessionProvider>();
    final repo = context.read<AppServices>().customers;
    switch (v) {
      case 'edit':
        final id = await Navigator.push<String>(
            context, MaterialPageRoute(builder: (_) => AddCustomerScreen(existing: c)));
        if (id != null && mounted) _load();
      case 'archive':
        await repo.setArchived(c.id, !c.isArchived, byUserId: session.user?.id ?? 'unknown');
        if (mounted) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _customer;
    final isOwner = context.watch<SessionProvider>().isOwner;
    return Scaffold(
      appBar: AppBar(
        title: Text(c?.name ?? ''),
        actions: [
          if (c != null)
            PopupMenuButton<String>(
              iconSize: 28,
              onSelected: _menu,
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text(S.edit)),
                if (isOwner)
                  PopupMenuItem(value: 'archive', child: Text(c.isArchived ? S.unarchive : S.archive)),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text('خطأ: $_error'))
                : _body(c!, isOwner),
      ),
    );
  }

  Widget _body(Customer c, bool isOwner) {
    final speech = context.read<SpeechService>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: photo + name + speaker + phone
          Row(
            children: [
              CustomerAvatar(name: c.name, photoPath: c.photoPath, size: 88,
                  borderColor: AppColors.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.phone_rounded,
                            size: 16,
                            color: c.phone == null ? AppColors.outline : AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(c.phone ?? S.noPhone,
                            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                      ],
                    ),
                    if (c.isArchived)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.outline, borderRadius: BorderRadius.circular(8)),
                        child: const Text(S.archived, style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
              ),
              _RoundIcon(
                icon: Icons.volume_up_rounded,
                onTap: () {
                  final b = _balances.isEmpty ? null : _balances.first.balance;
                  speech.speak(b == null
                      ? c.name
                      : SpeechService.balanceSentence(c.name, b));
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Big balance card(s)
          _BalanceCard(balances: _balances),
          const SizedBox(height: 14),
          // Action row
          Row(
            children: [
              Expanded(
                child: _Action(
                    icon: Icons.arrow_downward_rounded,
                    label: S.took1,
                    color: AppColors.debt,
                    filled: true,
                    enabled: !c.isArchived,
                    onTap: () => _newTx(TxType.debit)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Action(
                    icon: Icons.arrow_upward_rounded,
                    label: S.paid1,
                    color: AppColors.payment,
                    filled: true,
                    onTap: () => _newTx(TxType.credit)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Action(
                    icon: Icons.chat_rounded,
                    label: S.whatsapp,
                    color: AppColors.primary,
                    enabled: c.phoneE164 != null,
                    onTap: () => _remind(true)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Action(
                    icon: Icons.sms_rounded,
                    label: S.sms,
                    color: AppColors.primary,
                    enabled: c.phoneE164 != null,
                    onTap: () => _remind(false)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Action(
                    icon: Icons.description_rounded,
                    label: S.statement,
                    color: AppColors.primary,
                    onTap: () => Navigator.pushNamed(context, AppRoutes.reports)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(S.recentTransactions,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              TextButton.icon(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.transactions,
                    arguments: c.id),
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                iconAlignment: IconAlignment.end,
                label: const Text(S.seeAll),
              ),
            ],
          ),
          Expanded(
            child: _recent.isEmpty
                ? const Center(
                    child: Text(S.noTransactionsYet,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 16)))
                : ListView.separated(
                    itemCount: _recent.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => TxTile(
                      item: _recent[i],
                      showCustomer: false,
                      onTap: () async {
                        await Navigator.pushNamed(context, AppRoutes.txDetail,
                            arguments: _recent[i].tx.id);
                        if (mounted) _load();
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final List<CustomerBalance> balances;
  const _BalanceCard({required this.balances});

  @override
  Widget build(BuildContext context) {
    final main = balances.isEmpty ? null : balances.first.balance;
    final settled = main == null || main.isZero;
    final color = settled ? AppColors.payment : (main.isNegative ? AppColors.payment : AppColors.debt);
    final bg = settled
        ? AppColors.paymentContainer
        : (main.isNegative ? AppColors.paymentContainer : AppColors.debtContainer);
    final label = settled ? S.settled : (main.isNegative ? S.inCredit : S.owes);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 4),
          if (settled)
            Icon(Icons.check_circle_rounded, size: 56, color: color)
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(MoneyFormat.amount(main.abs),
                    style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: color,
                        height: 1.1,
                        fontFeatures: const [FontFeature.tabularFigures()])),
                const SizedBox(width: 8),
                Text(main.currency.shortName,
                    style: TextStyle(fontSize: 20, color: color, fontWeight: FontWeight.w600)),
              ],
            ),
          if (balances.length > 1) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 14,
              children: [
                for (final b in balances.skip(1))
                  if (!b.balance.isZero)
                    Text(
                      '${b.balance.isNegative ? S.inCredit : S.owes} ${MoneyFormat.withName(b.balance.abs)}',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: b.balance.isNegative ? AppColors.payment : AppColors.debt),
                    ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;
  final bool enabled;
  final VoidCallback onTap;
  const _Action({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : color;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: filled ? color : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            height: 72,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 28, color: fg),
                const SizedBox(height: 4),
                Text(label,
                    maxLines: 1,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.1),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
            width: 56, height: 56, child: Icon(icon, color: AppColors.primary, size: 30)),
      ),
    );
  }
}
