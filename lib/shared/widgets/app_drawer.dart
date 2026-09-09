import 'dart:math' as math;

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
  final String? userPhotoPath;
  final bool isOwner;
  final int overdueCount;
  final bool activated;
  final String currentRoute;
  final VoidCallback? onLogout;

  const AppDrawer({
    super.key,
    required this.shopName,
    required this.userName,
    this.userPhotoPath,
    required this.isOwner,
    required this.overdueCount,
    required this.activated,
    required this.currentRoute,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_DrawerItem>[
      const _DrawerItem(S.home, Icons.home_outlined, AppRoutes.home),
      const _DrawerItem(S.customers, Icons.people_outline_rounded, AppRoutes.customers),
      const _DrawerItem(S.transactions, Icons.receipt_long_outlined, AppRoutes.transactions),
      _DrawerItem(S.overdue, Icons.notifications_outlined, AppRoutes.overdue,
          badge: overdueCount),
      if (isOwner)
        const _DrawerItem(S.reports, Icons.bar_chart_outlined, AppRoutes.reports),
      if (isOwner)
        const _DrawerItem(S.currencies, Icons.savings_outlined, AppRoutes.currencies,
            hint: 'ر.ي / ر.س / \$'),
      if (isOwner)
        const _DrawerItem(S.backup, Icons.cloud_outlined, AppRoutes.backup),
      if (isOwner)
        const _DrawerItem(S.workers, Icons.badge_outlined, AppRoutes.workers),
      const _DrawerItem(S.settings, Icons.settings_outlined, AppRoutes.settings),
    ];

    return Drawer(
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _GeometricPattern())),
          SafeArea(
            child: Column(
              children: [
                _Header(
                    shopName: shopName,
                    userName: userName,
                    photoPath: userPhotoPath,
                    isOwner: isOwner),
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
                          item: _DrawerItem(S.activation, Icons.key_outlined,
                              AppRoutes.activation,
                              pill: activated ? S.activated : S.trial),
                          selected: currentRoute == AppRoutes.activation,
                        ),
                      _Tile(
                        item: const _DrawerItem(
                            S.voiceHelp, Icons.headset_mic_outlined, AppRoutes.voiceHelp),
                        selected: false,
                      ),
                      if (onLogout != null)
                        _Tile(
                          item: const _DrawerItem(S.logout, Icons.logout_rounded, ''),
                          selected: false,
                          onTapOverride: onLogout,
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
  final String? photoPath;
  final bool isOwner;
  const _Header(
      {required this.shopName,
      required this.userName,
      this.photoPath,
      required this.isOwner});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          CustomerAvatar(
              name: userName, photoPath: photoPath, size: 64, borderColor: Colors.white),
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
  final VoidCallback? onTapOverride;
  const _Tile({required this.item, required this.selected, this.onTapOverride});

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
            if (onTapOverride != null) {
              onTapOverride!();
              return;
            }
            if (!selected) {
              Navigator.of(context).pushNamedAndRemoveUntil(
                item.route,
                (r) => r.settings.name == AppRoutes.home,
              );
            }
          },
          child: SizedBox(
            height: 58,
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(item.icon, color: Colors.white, size: 26),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.label,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
                      if (item.hint != null)
                        Text(item.hint!,
                            style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                ),
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

/// Subtle Islamic 8-point star lattice, fading out toward the bottom
/// (docs/03 §6.2). Very low opacity so text stays fully legible.
class _GeometricPattern extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cell = 64.0;
    final stroke = Paint()
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    for (double cy = cell / 2; cy < size.height * 0.75; cy += cell) {
      final fade = 1 - (cy / (size.height * 0.75));
      stroke.color = Colors.white.withValues(alpha: 0.10 * fade);
      for (double cx = cell / 2; cx < size.width + cell; cx += cell) {
        _star(canvas, Offset(cx, cy), cell * 0.36, stroke);
      }
    }
  }

  void _star(Canvas c, Offset o, double r, Paint p) {
    // two overlapping squares rotated 45° = 8-point star
    for (final rot in [0.0, math.pi / 4]) {
      final path = Path();
      for (var i = 0; i < 4; i++) {
        final a = rot + i * math.pi / 2;
        final pt = Offset(o.dx + r * math.cos(a), o.dy + r * math.sin(a));
        i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
      path.close();
      c.drawPath(path, p);
    }
  }



  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
