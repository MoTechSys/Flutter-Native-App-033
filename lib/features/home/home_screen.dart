import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_routes.dart';
import '../../core/money/money.dart';
import '../../core/money/money_format.dart';
import '../../core/money/arabic_words.dart';
import '../../data/app_services.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../data/session/session_provider.dart';
import '../../shared/services/speech_service.dart';
import '../../shared/l10n/ar_strings.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/app_drawer.dart';
import '../../shared/widgets/customer_avatar.dart';
import 'widgets/hero_card.dart';
import 'widgets/quick_action_card.dart';

/// Home = dashboard only (D2). No vertical scroll (D3).
/// Layout mirrors docs/design/mockups/01_home_final.png — vertical space is
/// distributed with flex so the screen is always filled, never half-empty.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppServices>().dashboard.load();
  }

  /// Reload after any navigation away (a transaction may have been saved).
  Future<void> _push(String route, {Object? args}) async {
    await Navigator.pushNamed(context, route, arguments: args);
    if (mounted) setState(() => _future = context.read<AppServices>().dashboard.load());
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    return FutureBuilder<DashboardData>(
      future: _future,
      builder: (context, snap) {
        final data = snap.data;
        return Scaffold(
          drawer: AppDrawer(
            shopName: session.shop?.name ?? S.appName,
            userName: session.user?.name ?? '',
            userPhotoPath: session.user?.photoPath,
            isOwner: session.isOwner,
            overdueCount: data?.overdue.length ?? 0,
            activated: false,
            currentRoute: AppRoutes.home,
            onLogout: session.users.length > 1 || session.user?.hasPin == true
                ? () => session.logout()
                : null,
          ),
          body: SafeArea(
            child: snap.hasError
                ? Center(child: Text('خطأ: ${snap.error}'))
                : data == null
                    ? const Center(child: CircularProgressIndicator())
                    : _Dashboard(data: data, push: _push),
          ),
        );
      },
    );
  }
}

class _Dashboard extends StatelessWidget {
  final DashboardData data;
  final Future<void> Function(String route, {Object? args}) push;
  const _Dashboard({required this.data, required this.push});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(data: data, push: push),
          const SizedBox(height: 12),
          Expanded(flex: 24, child: HeroCard(data: data)),
          const SizedBox(height: 12),
          Expanded(
            flex: 21,
            child: Row(
              children: [
                Expanded(child: _OverdueCard(items: data.overdue, push: push)),
                const SizedBox(width: 12),
                Expanded(child: _TodayCard(data: data)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            flex: 14,
            child: Row(
              children: [
                Expanded(
                  child: QuickActionCard(
                    icon: Icons.people_alt_rounded,
                    label: S.customers,
                    onTap: () => push(AppRoutes.customers),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: QuickActionCard(
                    icon: Icons.add_circle_rounded,
                    label: S.newTransaction,
                    emphasized: true,
                    onTap: () => push(AppRoutes.newTransaction),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: QuickActionCard(
                    icon: Icons.bar_chart_rounded,
                    label: S.reports,
                    onTap: () => push(AppRoutes.reports),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: QuickActionCard(
                    icon: Icons.notifications_active_rounded,
                    label: S.overdue,
                    badge: data.overdue.length,
                    onTap: () => push(AppRoutes.overdue),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(S.recentTransactions,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => push(AppRoutes.transactions),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(S.seeAll,
                          style: TextStyle(
                              color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                      Icon(Icons.chevron_left_rounded,
                          size: 20, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(flex: 19, child: _RecentRow(items: data.recent, push: push)),
        ],
      ),
    );
  }
}

/// ☰ right (RTL start) • title right-aligned under it • 🔊 left.
class _Header extends StatelessWidget {
  final DashboardData data;
  final Future<void> Function(String route, {Object? args}) push;
  const _Header({required this.data, required this.push});
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 56dp touch target (docs/03 §4)
        SizedBox(
          width: 56,
          height: 56,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Scaffold.of(context).openDrawer(),
            child: const Center(
              child: Icon(Icons.menu_rounded, size: 30, color: AppColors.textPrimary),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(S.appNamePlain,
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      height: 1.05)),
              Text(context.watch<SessionProvider>().shop?.name ?? '',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.1)),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.zero,
          child: Material(
            color: AppColors.paymentContainer,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                final t = data.primaryTotal;
                context.read<SpeechService>().speak(t.isZero
                    ? 'لا ديون عند الناس'
                    : 'لك عند الناس ${ArabicWords.money(t)}. المتأخرون ${data.overdue.length}');
              },
              onLongPress: () => context.read<SpeechService>().speak(S.owedToYou),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.volume_up_rounded, size: 24, color: AppColors.primary),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OverdueCard extends StatelessWidget {
  final List<OverdueItem> items;
  final Future<void> Function(String route, {Object? args}) push;
  const _OverdueCard({required this.items, required this.push});

  @override
  Widget build(BuildContext context) {
    final shown = items.length > 3 ? 3 : items.length;
    return Material(
      color: AppColors.debtContainer,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => push(AppRoutes.overdue),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('متأخرين',
                  style: TextStyle(
                      fontSize: 18, color: AppColors.debt, fontWeight: FontWeight.w700)),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('${items.length}',
                          style: const TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w800,
                              color: AppColors.debt,
                              height: 1)),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 40,
                child: Stack(
                  children: [
                    for (var i = shown - 1; i >= 0; i--)
                      PositionedDirectional(
                        start: i * 26.0,
                        child: CustomerAvatar(
                          name: items[i].name,
                          photoPath: items[i].photoPath,
                          size: 40,
                          borderColor: Colors.white,
                          borderWidth: 2,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  final DashboardData data;
  const _TodayCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.accentContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(S.today,
              style: TextStyle(fontSize: 18, color: AppColors.accent, fontWeight: FontWeight.w700)),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _line(Icons.north_east_rounded, AppColors.primary, '+', data.todayTook),
                const SizedBox(height: 8),
                _line(Icons.south_east_rounded, AppColors.debt, '−', data.todayPaid),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(IconData icon, Color color, String sign, Money money) => Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 6),
          Text('$sign${MoneyFormat.amount(money)}',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      );
}

/// Single horizontal row of avatars (D4). Exactly 5 visible, filling the
/// width; more items scroll horizontally. Tap = new tx for that customer.
class _RecentRow extends StatelessWidget {
  final List<RecentItem> items;
  final Future<void> Function(String route, {Object? args}) push;
  const _RecentRow({required this.items, required this.push});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
          child: Text(S.noTransactionsYet, style: TextStyle(color: AppColors.textSecondary)));
    }
    return LayoutBuilder(
      builder: (context, c) {
        const visible = 5;
        const gap = 10.0;
        final itemW = (c.maxWidth - gap * (visible - 1)) / visible;
        // Use the available height too: avatar + 8 gap + ~26 chip, capped by width.
        final byHeight = c.maxHeight - 8 - 26 - 8;
        final avatar = (itemW - 6).clamp(44.0, 80.0).clamp(44.0, byHeight.clamp(44.0, 80.0));
        return ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: items.length > visible
              ? const BouncingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: gap),
          itemBuilder: (context, i) {
            final it = items[i];
            final debt = !it.tx.signedEffect.isNegative;
            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => push(AppRoutes.newTransaction, args: it.tx.customerId),
              onLongPress: () => push(AppRoutes.customerDetail, args: it.tx.customerId),
              child: SizedBox(
                width: itemW,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    CustomerAvatar(name: it.customerName, photoPath: it.photoPath, size: avatar),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: debt ? AppColors.debtContainer : AppColors.paymentContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Not colour-only: arrow + sign (docs/03 §2)
                          Icon(
                            debt ? Icons.south_east_rounded : Icons.north_east_rounded,
                            size: 12,
                            color: debt ? AppColors.debt : AppColors.payment,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            MoneyFormat.amount(it.tx.amount),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: debt ? AppColors.debt : AppColors.payment,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
