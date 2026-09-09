import 'package:flutter/material.dart';

import '../../../core/money/currency.dart';
import '../../../core/money/money_format.dart';

/// Denominations shown in the banknote grid, per currency (docs/03 §6.4).
/// Colours approximate the real notes so the illiterate user recognises them.
class Denomination {
  final int major;
  final Color color;
  final Color ink;
  const Denomination(this.major, this.color, this.ink);

  static const yer = [
    Denomination(1000, Color(0xFF5E4B8B), Color(0xFF2E1F55)), // بنفسجي
    Denomination(500, Color(0xFF2F8F83), Color(0xFF0F4F47)), // أخضر مزرق
    Denomination(250, Color(0xFFB8733A), Color(0xFF6B3D12)), // برتقالي بني
    Denomination(200, Color(0xFF8A8A4B), Color(0xFF4F4F1F)), // زيتي
    Denomination(100, Color(0xFFC0443F), Color(0xFF7A1F1C)), // أحمر
    Denomination(50, Color(0xFF4F6D8F), Color(0xFF243A55)), // أزرق رصاصي
  ];

  static const sar = [
    Denomination(500, Color(0xFF6C4F9E), Color(0xFF3A2662)),
    Denomination(200, Color(0xFF9E7A3A), Color(0xFF5C4413)),
    Denomination(100, Color(0xFFB04A4A), Color(0xFF6E1F1F)),
    Denomination(50, Color(0xFF3F8F5A), Color(0xFF1B5A31)),
    Denomination(10, Color(0xFF9A6B3E), Color(0xFF5C3B17)),
    Denomination(5, Color(0xFF6A7F3A), Color(0xFF3B4A17)),
  ];

  static const usd = [
    Denomination(100, Color(0xFF4A7A5A), Color(0xFF1F3F2B)),
    Denomination(50, Color(0xFF5A7A6A), Color(0xFF243F31)),
    Denomination(20, Color(0xFF5F7F6F), Color(0xFF283F34)),
    Denomination(10, Color(0xFF65846F), Color(0xFF2B4034)),
    Denomination(5, Color(0xFF6A8A70), Color(0xFF2E4536)),
    Denomination(1, Color(0xFF6F8F73), Color(0xFF314A37)),
  ];

  static List<Denomination> forCurrency(Currency c) {
    switch (c.code) {
      case 'SAR':
        return sar;
      case 'USD':
        return usd;
      default:
        return yer;
    }
  }
}

/// A drawn banknote: coloured rounded rectangle, faint pattern, big number
/// in both digit systems. Tappable with a count badge.
class BanknoteButton extends StatelessWidget {
  final Denomination d;
  final int count;
  final VoidCallback onAdd;
  final VoidCallback? onRemove;
  const BanknoteButton({
    super.key,
    required this.d,
    required this.count,
    required this.onAdd,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onRemove,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onAdd,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: BanknoteFace(d: d)),
              if (count > 0)
                PositionedDirectional(
                  top: -6,
                  end: -6,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 30),
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1F1E),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text('×$count',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                )
              else
                PositionedDirectional(
                  top: 6,
                  end: 6,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9), shape: BoxShape.circle),
                    child: Icon(Icons.add_rounded, size: 20, color: d.ink),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The note artwork itself (also used small in the "selected notes" strip).
class BanknoteFace extends StatelessWidget {
  final Denomination d;
  final bool compact;
  const BanknoteFace({super.key, required this.d, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final text = MoneyFormat.toArabicDigits('${d.major}');
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 6 : 14),
        gradient: LinearGradient(
          colors: [d.color.withValues(alpha: 0.85), d.color],
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        border: Border.all(color: d.ink.withValues(alpha: 0.5), width: compact ? 1 : 1.5),
      ),
      child: CustomPaint(
        painter: _NotePattern(d.ink.withValues(alpha: 0.18)),
        child: Padding(
          padding: EdgeInsets.all(compact ? 3 : 8),
          child: compact
              ? Center(
                  child: Text(text,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          shadows: [Shadow(color: d.ink, blurRadius: 2)])),
                )
              : Row(
                  children: [
                    // Small landmark-ish silhouette block (decor)
                    Container(
                      width: 26,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${d.major}',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 40,
                                    height: 1,
                                    fontWeight: FontWeight.w900,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                    shadows: [Shadow(color: d.ink, blurRadius: 3)])),
                            Text(text,
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    fontSize: 20,
                                    height: 1.1,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _NotePattern extends CustomPainter {
  final Color color;
  _NotePattern(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    // Guilloche-like concentric arcs in the corner + border inset
    final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(4, 4, size.width - 8, size.height - 8), const Radius.circular(10));
    canvas.drawRRect(r, p);
    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.5), i * 9.0, p);
    }
  }

  @override
  bool shouldRepaint(covariant _NotePattern old) => old.color != color;
}
