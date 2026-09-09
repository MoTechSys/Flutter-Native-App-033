import 'package:flutter/material.dart';

import '../../core/money/money.dart';
import '../../core/money/money_format.dart';
import '../theme/app_colors.dart';

/// Displays money with sign, arrow icon and semantic color.
/// Never relies on color alone (docs/03_DESIGN.md §2 colour-blindness rule).
class MoneyText extends StatelessWidget {
  final Money money;
  final double fontSize;
  final bool showSymbol;
  final bool showArrow;

  /// `true` → colour by debt semantics (positive=red owes, negative=green credit).
  /// `false` → neutral colour.
  final bool semantic;

  const MoneyText(
    this.money, {
    super.key,
    this.fontSize = 16,
    this.showSymbol = false,
    this.showArrow = false,
    this.semantic = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = !semantic
        ? AppColors.textPrimary
        : money.isNegative
            ? AppColors.payment
            : money.isZero
                ? AppColors.textSecondary
                : AppColors.debt;
    final text = showSymbol
        ? MoneyFormat.withSymbol(money.abs)
        : MoneyFormat.amount(money.abs);
    final icon = money.isNegative
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showArrow && !money.isZero) ...[
          Icon(icon, size: fontSize * 0.9, color: color),
          const SizedBox(width: 2),
        ],
        Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Small colored pill under avatars (home recent row).
class AmountChip extends StatelessWidget {
  final Money money;
  const AmountChip(this.money, {super.key});

  @override
  Widget build(BuildContext context) {
    final isDebt = !money.isNegative;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isDebt ? AppColors.debtContainer : AppColors.paymentContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${isDebt ? '−' : '+'}${MoneyFormat.amount(money.abs)}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isDebt ? AppColors.debt : AppColors.payment,
        ),
      ),
    );
  }
}
