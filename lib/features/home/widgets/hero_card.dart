import 'package:flutter/material.dart';

import '../../../core/money/money_format.dart';
import '../../../data/repositories/dashboard_repository.dart';
import '../../../shared/l10n/ar_strings.dart';
import '../../../shared/theme/app_colors.dart';

/// Emerald gradient hero: "لك عند الناس" + huge primary-currency total.
/// Other active currencies listed small underneath (R4: never summed).
class HeroCard extends StatelessWidget {
  final DashboardData data;
  const HeroCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final others = data.totalsByCurrency.entries
        .where((e) => e.key != data.primaryCurrency && !e.value.isZero)
        .toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(S.owedToYou,
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      MoneyFormat.amount(data.primaryTotal),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(data.primaryCurrency.symbol,
                        style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  ],
                ),
                if (others.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 12,
                    children: [
                      for (final e in others)
                        Text(MoneyFormat.withSymbol(e.value),
                            style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: 90,
            height: 44,
            child: CustomPaint(painter: _Sparkline()),
          ),
        ],
      ),
    );
  }
}

/// Decorative sparkline (static in Phase 0; live 30-day series in Phase 2).
class _Sparkline extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pts = [0.7, 0.55, 0.62, 0.4, 0.45, 0.3, 0.35, 0.2];
    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      final x = size.width * i / (pts.length - 1);
      final y = size.height * pts[i];
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
