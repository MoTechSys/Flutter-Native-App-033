import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ledger/ledger_errors.dart';
import '../../core/ledger/ledger_models.dart';
import '../../core/ledger/tx_type.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../data/app_services.dart';
import '../../data/models/customer.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/session/session_provider.dart';
import '../../shared/l10n/ar_strings.dart';
import '../../shared/services/speech_service.dart';
import '../../shared/theme/app_colors.dart';
import '../customers/customers_screen.dart';
import 'steps/amount_step.dart';
import 'steps/confirm_step.dart';
import 'steps/type_step.dart';
import 'undo_bar.dart';

/// Draft being built across the 4 steps (docs/03 §6.4).
class TxDraft {
  Customer customer;
  TxType? type;
  Money? amount;
  Map<int, int> notes = {}; // denomination major → count
  String? noteText;
  String? receiptPhotoPath;
  DateTime? dueDate;
  TxDraft(this.customer);
}

/// Entry point. Pushes the steps; returns true when a transaction was saved.
/// Skips step 1 when [customerId] is given, step 2 when [type] is given.
class NewTransactionFlow {
  NewTransactionFlow._();

  static Future<bool> start(
    BuildContext context, {
    String? customerId,
    TxType? type,
  }) async {
    final services = context.read<AppServices>();

    String? id = customerId;
    if (id == null) {
      id = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const CustomersScreen(pickMode: true)),
      );
      if (id == null || !context.mounted) return false;
    }
    final customer = await services.customers.getById(id);
    if (customer == null || !context.mounted) return false;

    final draft = TxDraft(customer)..type = type;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _FlowHost(draft: draft, skipType: type != null),
      ),
    );
    return saved ?? false;
  }
}

/// Hosts a nested navigator so the 3 remaining steps slide as separate
/// screens (D3: each step is its own screen) but pop back as one unit.
class _FlowHost extends StatefulWidget {
  final TxDraft draft;
  final bool skipType;
  const _FlowHost({required this.draft, required this.skipType});

  @override
  State<_FlowHost> createState() => _FlowHostState();
}

class _FlowHostState extends State<_FlowHost> {
  final _nav = GlobalKey<NavigatorState>();
  Money? _currentBalance;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final s = context.read<AppServices>();
    final cur = await s.customers.primaryCurrency();
    final b = await s.ledger.balance(widget.draft.customer.id, cur);
    if (mounted) setState(() => _currentBalance = b.balance);
  }

  void _goAmount() => _nav.currentState!.push(_route(_amountStep()));
  void _goConfirm() => _nav.currentState!.push(_route(_confirmStep()));

  Route<void> _route(Widget w) => MaterialPageRoute(builder: (_) => w);

  Widget _typeStep() => TypeStep(
        draft: widget.draft,
        isOwner: context.read<SessionProvider>().isOwner,
        onNext: (t) {
          widget.draft.type = t;
          _goAmount();
        },
        onCancel: () => Navigator.pop(context, false),
      );

  Widget _amountStep() => AmountStep(
        draft: widget.draft,
        currentBalance: _currentBalance,
        onBalanceCurrencyChanged: (Currency c) async {
          final b = await context.read<AppServices>().ledger.balance(widget.draft.customer.id, c);
          if (mounted) setState(() => _currentBalance = b.balance);
        },
        onNext: () => _goConfirm(),
      );

  Widget _confirmStep() => ConfirmStep(
        draft: widget.draft,
        currentBalance: _currentBalance,
        saving: _saving,
        onSave: _save,
      );

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final d = widget.draft;
    final s = context.read<AppServices>();
    final session = context.read<SessionProvider>();
    final speech = context.read<SpeechService>();
    final st = context.read<SettingsRepository>();
    try {
      final tx = await s.ledger.record(
        NewTransaction(
          customerId: d.customer.id,
          type: d.type!,
          amount: d.amount!,
          noteText: d.noteText,
          receiptPhotoPath: d.receiptPhotoPath,
          dueDate: d.dueDate,
        ),
        session.actor,
      );
      final newBal = await s.ledger.balance(d.customer.id, d.amount!.currency);
      // Owner alert on big payment by a worker (docs/06 phase 2).
      final threshold = st.get<int>(SettingsRepository.kBigPaymentAlertMinor);
      if (!session.isOwner && d.type == TxType.credit && threshold > 0 && d.amount!.minor >= threshold) {
        await s.db.insert('audit_log', {
          'id': tx.id, // same id → one alert per tx (PK)
          'entity': 'alert',
          'entity_id': tx.id,
          'action': 'big_payment',
          'actor_id': session.user?.id,
          'at': DateTime.now().toUtc().millisecondsSinceEpoch,
          'after_json': '{"amount":${d.amount!.minor},"customer":"${d.customer.id}"}',
          'device_id': s.deviceId,
        }).catchError((_) => 0);
      }
      speech.speak(SpeechService.transactionSentence(
        customerName: d.customer.name,
        type: d.type!,
        amount: d.amount!,
        newBalance: newBal.balance,
      ));
      if (!mounted) return;
      Navigator.pop(context, true);
      // Undo bar on the screen we return to (8s → auto reversal, R1).
      UndoBar.show(
        ScaffoldMessenger.of(context),
        onUndo: () async {
          try {
            await s.ledger.reverse(tx.id, session.actor.copyWithReverse(),
                reason: S.undoByUser);
            speech.speak(S.undone);
          } on LedgerError catch (e) {
            debugPrint('undo failed: ${e.messageAr}');
          }
        },
      );
    } on LedgerError catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.messageAr, style: const TextStyle(fontSize: 16)),
        backgroundColor: AppColors.debt,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('تعذّر الحفظ: $e'),
        backgroundColor: AppColors.debt,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = _nav.currentState!;
        if (nav.canPop()) {
          nav.pop();
        } else {
          Navigator.pop(context, false);
        }
      },
      child: Navigator(
        key: _nav,
        onGenerateRoute: (_) => _route(widget.skipType ? _amountStep() : _typeStep()),
      ),
    );
  }
}

extension on Actor {
  /// The "undo" bar must work for workers too (their own action, within 8s).
  /// It is still a full reversal row with reason "تراجع المستخدم" (R1).
  Actor copyWithReverse() => Actor(
        userId: userId,
        name: name,
        isOwner: isOwner,
        canReverse: true,
        canAdjust: canAdjust,
        canBackdateIntoLocked: canBackdateIntoLocked,
      );
}
