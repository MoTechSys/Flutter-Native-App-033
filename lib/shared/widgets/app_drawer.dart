import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../l10n/ar_strings.dart';
import '../theme/app_colors.dart';
import 'customer_avatar.dart';

/// Right-side drawer. Only the 9 main routes (docs/03_DESIGN.md §6.2).
/// Worker-hidden items: reports, currencies, backup, workers, activation.
class AppDrawer extends StatelessWidget {
  final String shopName;
  final String userName;
  final bool isOwner;
  final int overdueCount;
  final bool activated;
  final String currentRoute;

  const AppDrawer({
    super.key,
    required this.shopName,
    required this.userName,
    required this.isOwner,
    required this.overdueCount,
    required this.activated,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_DrawerItem>[
      const _DrawerItem(S.home, Icons.home_rounded, AppRoutes.home),
      const _DrawerItem(S.customers, Icons.people_alt_rounded, AppRoutes.customers),
      const _DrawerItem(S.transactions, Icons.receipt_long_rounded, AppRoutes.transactions),
      _DrawerItem(S.overdue, Icons.notifications_active_rounded, AppRoutes.overdue,
          badge: overdueCount),
      if (isOwner)
        const _DrawerItem(S.reports, Icons.bar_chart_rounded, AppRoutes.reports),
      if (isOwner)
        const _DrawerItem(S.currencies, Icons.currency_exchange_rounded, AppRoutes.currencies,
            hint: 'ر.ي / ر.س / \$'),
      if (isOwner)
        const _DrawerItem(S.backup, Icons.cloud_upload_rounded, AppRoutes.backup),
      if (isOwner)
        const _DrawerItem(S.workers, Icons.badge_rounded, AppRoutes.workers),
      const _DrawerItem(S.settings, Icons.settings_rounded, AppRoutes.settings),
    ];

    return Drawer(
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _GeometricPattern())),
          SafeArea(
            child: Column(
              children: [
                _Header(shopName: shopName, userName: userName, isOwner: isOwner),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      for (final it in items)
                        _Tile(item: it, selected: it.route == currentRoute),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Divider(color: Colors.white24),
                      ),
                      if (isOwner)
                        _Tile(
                          item: _DrawerItem(S.activation, Icons.vpn_key_rounded,
                              AppRoutes.activation,
                              pill: activated ? S.activated : S.trial),
                          selected: currentRoute == AppRoutes.activation,
                        ),
                      _Tile(
                        item: const _DrawerItem(
                            S.voiceHelp, Icons.headset_mic_rounded, AppRoutes.voiceHelp),
                        selected: false,
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(S.appName,
                          style: TextStyle(
                              color: AppColors.darkAccent,
                              fontSize: 20,
                              fontWeight: FontWeight.w700)),
                      Text('${S.version} 0.1.0',
                          style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String shopName;
  final String userName;
  final bool isOwner;
  const _Header({required this.shopName, required this.userName, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          CustomerAvatar(name: userName, size: 60, borderColor: Colors.white),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shopName,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(userName,
                        style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.darkAccent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(isOwner ? S.owner : S.worker,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem {
  final String label;
  final IconData icon;
  final String route;
  final int badge;
  final String? hint;
  final String? pill;
  const _DrawerItem(this.label, this.icon, this.route,
      {this.badge = 0, this.hint, this.pill});
}

class _Tile extends StatelessWidget {
  final _DrawerItem item;
  final bool selected;
  const _Tile({required this.item, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? Colors.white.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.of(context).pop();
            if (!selected) {
              Navigator.of(context).pushNamedAndRemoveUntil(
                item.route,
                (r) => r.settings.name == AppRoutes.home,
              );
            }
          },
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(item.icon, color: Colors.white, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(item.label,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 17, fontWeight: FontWeight.w500)),
                ),
                if (item.hint != null)
                  Text(item.hint!,
                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
                if (item.badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.debt,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('${item.badge}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                if (item.pill != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.darkAccent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(item.pill!,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                const SizedBox(width: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Subtle diagonal geometric pattern (opacity 0.06) — docs/03 §6.2.
class _GeometricPattern extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    const step = 36.0;
    for (double x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), p);
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
