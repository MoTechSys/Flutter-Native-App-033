import 'package:flutter/material.dart';

import '../../core/ledger/tx_type.dart';
import '../../core/money/money_format.dart';
import '../../data/repositories/transactions_repository.dart';
import '../l10n/ar_strings.dart';
import '../theme/app_colors.dart';
import '../utils/date_labels.dart';
import 'customer_avatar.dart';

/// 72dp transaction row — mockup 03: photo • name + time • coloured amount
/// with arrow • small icons (🎤 voice, 📷 photo, ↩ reversed).
class TxTile extends StatelessWidget {
  final TxListItem item;
  final bool showCustomer;
  final VoidCallback? onTap;
  const TxTile({super.key, required this.item, this.showCustomer = true, this.onTap});

  @override
  Widget build(BuildContext context) {
    final tx = item.tx;
    final effect = tx.signedEffect;
    final isDebt = !effect.isNegative;
    final color = isDebt ? AppColors.debt : AppColors.payment;
    final dim = tx.isReversed;
    final subtitle = <Widget>[
      Text(DateLabels.time(tx.occurredAt),
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      if (tx.noteVoicePath != null) const _Mini(Icons.mic_rounded),
      if (tx.receiptPhotoPath != null) const _Mini(Icons.photo_camera_rounded),
      if (tx.noteText != null && tx.noteText!.isNotEmpty) const _Mini(Icons.notes_rounded),
      if (tx.isReversed) const _Mini(Icons.undo_rounded, color: AppColors.debt),
      if (tx.isReversal) const _Mini(Icons.replay_rounded, color: AppColors.textSecondary),
    ];

    return Opacity(
      opacity: dim ? 0.55 : 1,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: SizedBox(
            height: 72,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  if (showCustomer)
                    CustomerAvatar(name: item.customerName, photoPath: item.photoPath, size: 48)
                  else
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                          color: isDebt ? AppColors.debtContainer : AppColors.paymentContainer,
                          shape: BoxShape.circle),
                      child: Icon(
                          isDebt ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                          color: color),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          showCustomer ? item.customerName : _typeLabel(tx.type),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              decoration: dim ? TextDecoration.lineThrough : null),
                        ),
                        const SizedBox(height: 2),
                        Row(children: _withGaps(subtitle)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isDebt ? Icons.expand_more_rounded : Icons.expand_less_rounded,
                        color: color,
                        size: 22,
                      ),
                      Text(
                        '${isDebt ? '−' : '+'}${MoneyFormat.amount(effect.abs)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: color,
                          decoration: dim ? TextDecoration.lineThrough : null,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _typeLabel(TxType t) => switch (t) {
        TxType.debit => S.tookFromMe,
        TxType.credit => S.paidToMe,
        TxType.adjustDown => S.adjustDown,
        TxType.adjustUp => S.adjustUp,
        TxType.opening => 'رصيد سابق',
      };

  static List<Widget> _withGaps(List<Widget> ws) {
    final out = <Widget>[];
    for (var i = 0; i < ws.length; i++) {
      if (i > 0) out.add(const SizedBox(width: 6));
      out.add(ws[i]);
    }
    return out;
  }
}

class _Mini extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _Mini(this.icon, {this.color = AppColors.textSecondary});
  @override
  Widget build(BuildContext context) => Icon(icon, size: 14, color: color);
}
