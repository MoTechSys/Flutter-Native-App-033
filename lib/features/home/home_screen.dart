import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_routes.dart';
import '../../core/money/money_format.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../shared/l10n/ar_strings.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/app_drawer.dart';
import '../../shared/widgets/customer_avatar.dart';
import '../../shared/widgets/money_text.dart';
import 'widgets/hero_card.dart';
import 'widgets/quick_action_card.dart';

/// Home = dashboard only (decision D2). No vertical scroll (D3).
/// Layout mirrors docs/design/mockups/01_home_final.png.
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
    _future = context.read<DashboardRepository>().load();
  }

  Future<void> _reload() async {
    setState(() => _future = context.read<DashboardRepository>().load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, size: 28),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
            tooltip: 'القائمة',
          ),
        ),
        title: Column(
          children: [
            const Text(S.appName),
            Text('بقالة الأمل',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up_rounded, size: 26, color: AppColors.primary),
            onPressed: () {},
            tooltip: 'اقرأ لي',
          ),
        ],
      ),
      drawer: FutureBuilder<DashboardData>(
        future: _future,
        builder: (_, snap) => AppDrawer(
          shopName: 'بقالة الأمل',
          userName: 'صالح أحمد',
          isOwner: true,
          overdueCount: snap.data?.overdue.length ?? 0,
          activated: false,
          currentRoute: AppRoutes.home,
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<DashboardData>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(child: Text('خطأ: ${snap.error}'));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return _Dashboard(data: snap.data!, onRefresh: _reload);
          },
        ),
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  final DashboardData data;
  final Future<void> Function() onRefresh;
  const _Dashboard({required this.data, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        // Everything must fit; distribute vertical space with Expanded/flex.
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HeroCard(data: data),
              const SizedBox(height: 12),
              SizedBox(
                height: 112,
                child: Row(
                  children: [
                    Expanded(child: _OverdueCard(items: data.overdue)),
                    const SizedBox(width: 12),
                    Expanded(child: _TodayCard(data: data)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 96,
                child: Row(
                  children: [
                    Expanded(
                      child: QuickActionCard(
                        icon: Icons.people_alt_rounded,
                        label: S.customers,
                        onTap: () => Navigator.pushNamed(context, AppRoutes.customers),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: QuickActionCard(
                        icon: Icons.add_circle_rounded,
                        label: S.newTransaction,
                        emphasized: true,
                        onTap: () => Navigator.pushNamed(context, AppRoutes.newTransaction),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: QuickActionCard(
                        icon: Icons.bar_chart_rounded,
                        label: S.reports,
                        onTap: () => Navigator.pushNamed(context, AppRoutes.reports),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: QuickActionCard(
                        icon: Icons.notifications_active_rounded,
                        label: S.overdue,
                        badge: data.overdue.length,
                        onTap: () => Navigator.pushNamed(context, AppRoutes.overdue),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(S.recentTransactions,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.transactions),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(S.seeAll, style: TextStyle(fontWeight: FontWeight.w700)),
                        Icon(Icons.chevron_left_rounded, size: 20),
                      ],
                    ),
                  ),
                ],
              ),
              Expanded(child: _RecentRow(items: data.recent)),
            ],
          ),
        );
      },
    );
  }
}

class _OverdueCard extends StatelessWidget {
  final List<OverdueItem> items;
  const _OverdueCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.debtContainer,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.pushNamed(context, AppRoutes.overdue),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('متأخرين',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.debt, fontWeight: FontWeight.w700)),
              const Spacer(),
              Row(
                children: [
                  Text('${items.length}',
                      style: const TextStyle(
                          fontSize: 34, fontWeight: FontWeight.w800, color: AppColors.debt,
                          height: 1)),
                  const Spacer(),
                  SizedBox(
                    width: 84,
                    height: 36,
                    child: Stack(
                      children: [
                        for (var i = (items.length > 3 ? 2 : items.length - 1); i >= 0; i--)
                          Positioned(
                            right: i * 22.0,
                            child: CustomerAvatar(
                              name: items[i].name,
                              photoPath: items[i].photoPath,
                              size: 30,
                              borderColor: AppColors.debtContainer,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accentContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(S.today,
              style: TextStyle(fontSize: 13, color: AppColors.accent, fontWeight: FontWeight.w700)),
          const Spacer(),
          _line(Icons.arrow_downward_rounded, AppColors.debt, '+', data.todayTook),
          const SizedBox(height: 4),
          _line(Icons.arrow_upward_rounded, AppColors.payment, '−', data.todayPaid),
        ],
      ),
    );
  }

  Widget _line(IconData icon, Color color, String sign, money) => Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text('$sign${MoneyFormat.amount(money)}',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      );
}

/// Single horizontal row of avatars (decision D4). Tap = new tx for that customer.
class _RecentRow extends StatelessWidget {
  final List<RecentItem> items;
  const _RecentRow({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
          child: Text(S.noTransactionsYet, style: TextStyle(color: AppColors.textSecondary)));
    }
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(width: 14),
      itemBuilder: (context, i) {
        final it = items[i];
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.pushNamed(context, AppRoutes.newTransaction,
              arguments: it.tx.customerId),
          child: SizedBox(
            width: 72,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomerAvatar(name: it.customerName, photoPath: it.photoPath, size: 56),
                const SizedBox(height: 6),
                Text(it.customerName.split(' ').first,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                AmountChip(it.tx.signedEffect),
              ],
            ),
          ),
        );
      },
    );
  }
}
