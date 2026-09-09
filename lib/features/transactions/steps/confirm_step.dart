import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/money/money.dart';
import '../../../core/money/money_format.dart';
import '../../../shared/l10n/ar_strings.dart';
import '../../../shared/services/photo_service.dart';
import '../../../shared/services/speech_service.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/utils/date_labels.dart';
import '../../../shared/widgets/customer_avatar.dart';
import '../new_transaction_flow.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/l10n/tx_labels.dart';

/// Step 4: spoken summary + optional 📷 receipt, 📝 note, ⏰ due date, big save.
class ConfirmStep extends StatefulWidget {
  final TxDraft draft;
  final Money? currentBalance;
  final bool saving;
  final VoidCallback onSave;
  const ConfirmStep({
    super.key,
    required this.draft,
    required this.currentBalance,
    required this.saving,
    required this.onSave,
  });

  @override
  State<ConfirmStep> createState() => _ConfirmStepState();
}

class _ConfirmStepState extends State<ConfirmStep> {
  final _photos = PhotoService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _speak());
  }

  Money get _newBalance {
    final d = widget.draft;
    final cur = widget.currentBalance;
    final base = (cur != null && cur.currency == d.amount!.currency) ? cur.minor : 0;
    return Money(base + d.type!.sign * d.amount!.minor, d.amount!.currency);
  }

  void _speak() {
    final d = widget.draft;
    context.read<SpeechService>().speak(SpeechService.transactionSentence(
          customerName: d.customer.name,
          type: d.type!,
          amount: d.amount!,
          newBalance: _newBalance,
        ));
  }

  Future<void> _note() async {
    final ctrl = TextEditingController(text: widget.draft.noteText ?? '');
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(S.addNote),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          style: const TextStyle(fontSize: 18),
          decoration: const InputDecoration(hintText: 'مثال: كرتون حليب + سكر'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text(S.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text(S.done)),
        ],
      ),
    );
    if (v != null) setState(() => widget.draft.noteText = v.trim().isEmpty ? null : v.trim());
  }

  Future<void> _photo() async {
    final p = await _photos.pick(fromCamera: true, folder: 'receipts');
    if (p != null && mounted) setState(() => widget.draft.receiptPhotoPath = p);
  }

  Future<void> _due() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: widget.draft.dueDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: S.dueDate,
    );
    if (d != null) setState(() => widget.draft.dueDate = DateTime.utc(d.year, d.month, d.day));
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    final isDebt = d.type!.sign > 0;
    final color = isDebt ? AppColors.debt : AppColors.payment;
    final nb = _newBalance;

    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(), title: const Text(S.confirm)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CustomerAvatar(
                        name: d.customer.name, photoPath: d.customer.photoPath, size: 110,
                        borderColor: color, borderWidth: 4),
                    const SizedBox(height: 12),
                    Text(d.customer.name,
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      decoration: BoxDecoration(
                        color: isDebt ? AppColors.debtContainer : AppColors.paymentContainer,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(isDebt ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                  color: color, size: 30),
                              const SizedBox(width: 6),
                              Text(TxLabels.of(context, d.type!),
                                  style: TextStyle(
                                      fontSize: 22, fontWeight: FontWeight.w700, color: color)),
                            ],
                          ),
                          Text(MoneyFormat.withName(d.amount!),
                              style: TextStyle(
                                  fontSize: 46,
                                  height: 1.1,
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                  fontFeatures: const [FontFeature.tabularFigures()])),
                          const Divider(height: 20),
                          Text(
                            nb.isZero
                                ? 'يصير حسابه ${S.settled}'
                                : nb.isNegative
                                    ? '${S.willBeInCredit} ${MoneyFormat.withName(nb.abs)}'
                                    : '${S.newBalance} ${MoneyFormat.withName(nb)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _speak,
                      icon: const Icon(Icons.volume_up_rounded, size: 26),
                      label: const Text(S.listen, style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
              // Optional extras
              Row(
                children: [
                  Expanded(
                    child: _Extra(
                      icon: Icons.photo_camera_rounded,
                      label: S.receiptPhoto,
                      active: d.receiptPhotoPath != null,
                      onTap: _photo,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Extra(
                      icon: Icons.notes_rounded,
                      label: d.noteText == null ? S.addNote : d.noteText!,
                      active: d.noteText != null,
                      onTap: _note,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Extra(
                      icon: Icons.alarm_rounded,
                      label: d.dueDate == null ? S.dueDate : DateLabels.short(d.dueDate!),
                      active: d.dueDate != null,
                      onTap: _due,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 68,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: color),
                  onPressed: widget.saving ? null : widget.onSave,
                  icon: widget.saving
                      ? const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : const Icon(Icons.save_rounded, size: 32),
                  label: const Text(S.save, style: TextStyle(fontSize: 24)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  
}

class _Extra extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Extra({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = active ? AppColors.primary : AppColors.textSecondary;
    return Material(
      color: active ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          height: 72,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: c),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
