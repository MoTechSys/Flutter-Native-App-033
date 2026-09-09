import 'package:flutter/material.dart';

import '../../../core/money/money_format.dart';
import '../../../data/repositories/dashboard_repository.dart';
import '../../../shared/l10n/ar_strings.dart';
import '../../../shared/theme/app_colors.dart';

/// Emerald hero: label, huge primary-currency total + "ريال", and a
/// full-width sparkline along the bottom (mockup 01_home_final.png).
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
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A5340), AppColors.primaryLight],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 54,
            child: CustomPaint(painter: _Sparkline()),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(S.owedToYou,
                    style: TextStyle(
                        color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            MoneyFormat.amount(data.primaryTotal),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 52,
                              fontWeight: FontWeight.w800,
                              height: 1.0,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(data.primaryCurrency.nameAr.split(' ').first,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ),
                if (others.isNotEmpty)
                  Wrap(
                    spacing: 12,
                    children: [
                      for (final e in others)
                        Text('≈ ${MoneyFormat.withSymbol(e.value)}',
                            style: const TextStyle(color: Colors.white70, fontSize: 13)),
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

/// Decorative 30-day trend line across the card bottom (static in Phase 0;
/// wired to a real daily series in Phase 2).
class _Sparkline extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const pts = [0.82, 0.70, 0.74, 0.55, 0.62, 0.45, 0.50, 0.30, 0.36, 0.18];
    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      final x = size.width * i / (pts.length - 1);
      final y = size.height * pts[i];
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    // soft fill under the line
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.18), Colors.white.withValues(alpha: 0.0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
