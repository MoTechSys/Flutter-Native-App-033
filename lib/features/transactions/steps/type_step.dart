import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/ledger/tx_type.dart';
import '../../../shared/l10n/ar_strings.dart';
import '../../../shared/services/speech_service.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/customer_avatar.dart';
import '../new_transaction_flow.dart';
import '../../../shared/l10n/tx_labels.dart';

/// Step 2: two giant buttons 🔴 أخذ مني / 🟢 دفع لي (+ small "تسوية" for owner).
class TypeStep extends StatelessWidget {
  final TxDraft draft;
  final bool isOwner;
  final ValueChanged<TxType> onNext;
  final VoidCallback onCancel;
  const TypeStep({
    super.key,
    required this.draft,
    required this.isOwner,
    required this.onNext,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final speech = context.read<SpeechService>();
    final c = draft.customer;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: onCancel),
        title: const Text(S.chooseType),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CustomerAvatar(name: c.name, photoPath: c.photoPath, size: 64),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(c.name,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _Giant(
                  color: AppColors.debt,
                  icon: Icons.arrow_downward_rounded,
                  label: TxLabels.took(context),
                  hint: 'بضاعة بالدين',
                  onTap: () => onNext(TxType.debit),
                  onLongPress: () => speech.speak(TxLabels.took(context)),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _Giant(
                  color: AppColors.payment,
                  icon: Icons.arrow_upward_rounded,
                  label: TxLabels.paid(context),
                  hint: 'سدّد من حسابه',
                  onTap: () => onNext(TxType.credit),
                  onLongPress: () => speech.speak(TxLabels.paid(context)),
                ),
              ),
              if (isOwner) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => _adjustSheet(context),
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text(S.adjustment, style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _adjustSheet(BuildContext context) async {
    final t = await showModalBottomSheet<TxType>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              minTileHeight: 64,
              leading: const Icon(Icons.remove_circle_outline_rounded,
                  color: AppColors.payment, size: 30),
              title: const Text(S.adjustDown, style: TextStyle(fontSize: 18)),
              subtitle: const Text('خصم أو إعفاء لصالح الزبون'),
              onTap: () => Navigator.pop(ctx, TxType.adjustDown),
            ),
            ListTile(
              minTileHeight: 64,
              leading: const Icon(Icons.add_circle_outline_rounded,
                  color: AppColors.debt, size: 30),
              title: const Text(S.adjustUp, style: TextStyle(fontSize: 18)),
              subtitle: const Text('تصحيح لصالح المحل'),
              onTap: () => Navigator.pop(ctx, TxType.adjustUp),
            ),
            ListTile(
              minTileHeight: 64,
              leading: const Icon(Icons.menu_book_rounded, color: AppColors.accent, size: 30),
              title: const Text('رصيد سابق', style: TextStyle(fontSize: 18)),
              subtitle: const Text('نقل دين من الدفتر الورقي (مرة واحدة)'),
              onTap: () => Navigator.pop(ctx, TxType.opening),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (t != null) onNext(t);
  }
}

class _Giant extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _Giant({
    required this.color,
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(28),
      elevation: 2,
      shadowColor: color.withValues(alpha: 0.4),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
              child: Icon(icon, size: 64, color: Colors.white),
            ),
            const SizedBox(height: 14),
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(hint,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
