import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';

/// Square white tile: big icon + ONE word (docs/02 §C "icon + text together").
class QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;
  final bool emphasized;

  const QuickActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: emphasized ? AppColors.primary : AppColors.surface,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon,
                      size: 34, color: emphasized ? Colors.white : AppColors.primary),
                  const SizedBox(height: 6),
                  Text(label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: emphasized ? Colors.white : AppColors.textPrimary,
                      )),
                ],
              ),
            ),
            if (badge > 0)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.debt,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('$badge',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
