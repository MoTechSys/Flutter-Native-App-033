import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ledger/ledger_errors.dart';
import '../../core/ledger/ledger_models.dart';
import '../../core/money/money_format.dart';
import '../../data/app_services.dart';
import '../../data/models/customer.dart';
import '../../data/session/session_provider.dart';
import '../../shared/l10n/ar_strings.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/utils/date_labels.dart';
import '../../shared/widgets/customer_avatar.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/l10n/tx_labels.dart';

/// Transaction details + owner-only reversal with mandatory reason (R1, R9).
class TxDetailScreen extends StatefulWidget {
  final String txId;
  const TxDetailScreen({super.key, required this.txId});

  @override
  State<TxDetailScreen> createState() => _TxDetailScreenState();
}

class _TxDetailScreenState extends State<TxDetailScreen> {
  LedgerTx? _tx;
  LedgerTx? _linked; // the reversal or the original
  Customer? _customer;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = context.read<AppServices>();
    try {
      final tx = await s.ledger.getById(widget.txId);
      if (tx == null) throw StateError('not found');
      final linkedId = tx.reversedById ?? tx.reversesId;
      final linked = linkedId == null ? null : await s.ledger.getById(linkedId);
      final c = await s.customers.getById(tx.customerId);
      if (!mounted) return;
      setState(() {
        _tx = tx;
        _linked = linked;
        _customer = c;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _reverse() async {
    final ctrl = TextEditingController();
    final s = context.read<AppServices>();
    final actor = context.read<SessionProvider>().actor;
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(S.reverse),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('لا تُحذف الحركة؛ يُسجَّل قيد عكسي يلغي أثرها.',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: S.reverseReason),
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text(S.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.debt),
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text(S.reverse),
          ),
        ],
      ),
    );
    if (reason == null) return;
    try {
      await s.ledger.reverse(_tx!.id, actor, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(S.done)));
      _load();
    } on LedgerError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.messageAr), backgroundColor: AppColors.debt));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = context.watch<SessionProvider>().isOwner;
    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(), title: const Text(S.txDetails)),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text('خطأ: $_error'))
                : _body(isOwner),
      ),
    );
  }

  Widget _body(bool isOwner) {
    final tx = _tx!;
    final effect = tx.signedEffect;
    final isDebt = !effect.isNegative;
    final color = isDebt ? AppColors.debt : AppColors.payment;
    final name = _customer?.name ?? tx.customerNameSnap;
    final canReverse = isOwner && !tx.isReversed && !tx.isReversal;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  CustomerAvatar(name: name, photoPath: _customer?.photoPath, size: 96,
                      borderColor: color),
                  const SizedBox(height: 10),
                  Text(name,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: isDebt ? AppColors.debtContainer : AppColors.paymentContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Text(TxLabels.of(context, tx.type),
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700, color: color)),
                        const SizedBox(height: 4),
                        Text(
                          MoneyFormat.withName(tx.amount),
                          style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w800,
                              color: color,
                              decoration: tx.isReversed ? TextDecoration.lineThrough : null,
                              fontFeatures: const [FontFeature.tabularFigures()]),
                        ),
                        if (tx.isReversed)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                                color: AppColors.debt, borderRadius: BorderRadius.circular(999)),
                            child: const Text(S.reversed,
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          ),
                        if (tx.isReversal)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                                color: AppColors.textSecondary,
                                borderRadius: BorderRadius.circular(999)),
                            child: const Text(S.reversal,
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Row(Icons.event_rounded, 'التاريخ', DateLabels.full(tx.occurredAt)),
                  _Row(Icons.person_rounded, S.recordedBy, tx.userNameSnap),
                  if (tx.recordedAt.difference(tx.occurredAt).abs() > const Duration(minutes: 10))
                    _Row(Icons.history_rounded, 'وقت التسجيل', DateLabels.full(tx.recordedAt)),
                  if (tx.noteText != null && tx.noteText!.isNotEmpty)
                    _Row(Icons.notes_rounded, S.note, tx.noteText!),
                  if (tx.dueDate != null)
                    _Row(Icons.alarm_rounded, S.dueDate, DateLabels.short(tx.dueDate!)),
                  if (tx.overLimit)
                    const _Row(Icons.warning_amber_rounded, 'تنبيه', 'تجاوز حد الدين',
                        color: AppColors.accent),
                  if (tx.inLockedPeriod)
                    const _Row(Icons.lock_clock_rounded, 'تنبيه', 'سُجّلت في فترة مقفلة',
                        color: AppColors.accent),
                  if (_linked != null) ...[
                    const Divider(height: 28),
                    _Row(
                      tx.isReversed ? Icons.undo_rounded : Icons.replay_rounded,
                      tx.isReversed ? 'عُكست بواسطة' : 'تعكس الحركة',
                      '${_linked!.userNameSnap} — ${DateLabels.full(_linked!.recordedAt)}',
                    ),
                    if ((tx.isReversed ? _linked!.reversalReason : tx.reversalReason) != null)
                      _Row(Icons.info_outline_rounded, S.reverseReason,
                          (tx.isReversed ? _linked!.reversalReason : tx.reversalReason)!),
                  ],
                ],
              ),
            ),
          ),
          if (canReverse)
            SizedBox(
              height: 60,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.debt,
                  side: const BorderSide(color: AppColors.debt, width: 1.5),
                ),
                onPressed: _reverse,
                icon: const Icon(Icons.undo_rounded, size: 26),
                label: const Text(S.reverse, style: TextStyle(fontSize: 18)),
              ),
            ),
        ],
      ),
    );
  }

  
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  const _Row(this.icon, this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: color ?? AppColors.textSecondary),
          const SizedBox(width: 10),
          SizedBox(
            width: 96,
            child: Text(label,
                style: TextStyle(color: color ?? AppColors.textSecondary, fontSize: 15)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: color ?? AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}
