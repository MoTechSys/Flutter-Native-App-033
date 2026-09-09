import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/money/arabic_words.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_format.dart';
import '../../../data/app_services.dart';
import '../../../shared/l10n/ar_strings.dart';
import '../../../shared/services/speech_service.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/customer_avatar.dart';
import '../new_transaction_flow.dart';
import '../widgets/banknote.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/l10n/tx_labels.dart';

/// Step 3 — reference `04_amount_entry_banknotes_ref.png`:
/// customer + balance on top, huge amount, selected-notes strip, banknote
/// grid (tap = +1, long-press = −1) or keypad tab, currency chips, confirm
/// button coloured by type. All arithmetic in integer minor units (R2).
class AmountStep extends StatefulWidget {
  final TxDraft draft;
  final Money? currentBalance;
  final Future<void> Function(Currency) onBalanceCurrencyChanged;
  final VoidCallback onNext;
  const AmountStep({
    super.key,
    required this.draft,
    required this.currentBalance,
    required this.onBalanceCurrencyChanged,
    required this.onNext,
  });

  @override
  State<AmountStep> createState() => _AmountStepState();
}

class _AmountStepState extends State<AmountStep> {
  Currency _currency = Currency.yer;
  List<Currency> _active = const [Currency.yer];
  bool _keypad = false;
  String _typed = ''; // keypad digits (major units)
  final Map<int, int> _notes = {};

  @override
  void initState() {
    super.initState();
    _notes.addAll(widget.draft.notes);
    if (widget.draft.amount != null) {
      _currency = widget.draft.amount!.currency;
      if (_notes.isEmpty) {
        _typed = '${widget.draft.amount!.minor ~/ _pow10(_currency.minorUnits)}';
        _keypad = true;
      }
    }
    _loadCurrencies();
  }

  static int _pow10(int n) => n == 0 ? 1 : (n == 2 ? 100 : 1000);

  Future<void> _loadCurrencies() async {
    final db = context.read<AppServices>().db;
    final rows = await db.query('currencies', where: 'is_active = 1', orderBy: 'is_primary DESC, sort');
    if (!mounted) return;
    setState(() {
      _active = rows.map((r) => Currency.byCode(r['code'] as String)).toList();
      if (_active.isNotEmpty && !_active.contains(_currency)) _currency = _active.first;
    });
  }

  /// Sum in minor units — integer only (R2).
  Money get _amount {
    if (_keypad) {
      final major = int.tryParse(_typed) ?? 0;
      return Money(major * _pow10(_currency.minorUnits), _currency);
    }
    var minor = 0;
    for (final e in _notes.entries) {
      minor += e.key * _pow10(_currency.minorUnits) * e.value;
    }
    return Money(minor, _currency);
  }

  Money? get _newBalance {
    final cur = widget.currentBalance;
    if (cur == null || cur.currency != _currency) return null;
    final a = _amount;
    if (a.isZero) return null;
    return Money(cur.minor + widget.draft.type!.sign * a.minor, _currency);
  }

  void _add(int major) => setState(() => _notes[major] = (_notes[major] ?? 0) + 1);
  void _remove(int major) => setState(() {
        final n = (_notes[major] ?? 0) - 1;
        if (n <= 0) {
          _notes.remove(major);
        } else {
          _notes[major] = n;
        }
      });

  void _clear() => setState(() {
        _notes.clear();
        _typed = '';
      });

  void _key(String k) => setState(() {
        if (k == '⌫') {
          if (_typed.isNotEmpty) _typed = _typed.substring(0, _typed.length - 1);
        } else if (k == '000') {
          if (_typed.isNotEmpty && _typed.length <= 9) _typed += '000';
        } else if (_typed.length < 12 && !(_typed.isEmpty && k == '0')) {
          _typed += k;
        }
      });

  void _switchCurrency(Currency c) {
    setState(() {
      _currency = c;
      _notes.clear();
      _typed = '';
    });
    widget.onBalanceCurrencyChanged(c);
  }

  void _next() {
    final a = _amount;
    if (a.isZero) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(S.amountZero)));
      return;
    }
    widget.draft.amount = a;
    widget.draft.notes = Map.of(_notes);
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.draft.type!;
    final isDebt = type.sign > 0;
    final color = isDebt ? AppColors.debt : AppColors.payment;
    final amount = _amount;
    final speech = context.read<SpeechService>();
    final c = widget.draft.customer;
    final denoms = Denomination.forCurrency(_currency);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(TxLabels.of(context, type)),
        actions: [
          IconButton(
            iconSize: 28,
            tooltip: S.listen,
            onPressed: () => speech.speak(amount.isZero
                ? S.amountZero
                : ArabicWords.money(amount)),
            icon: const Icon(Icons.volume_up_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Customer + current balance
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(
                children: [
                  CustomerAvatar(name: c.name, photoPath: c.photoPath, size: 52, borderColor: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        Text(_balanceLine(widget.currentBalance),
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  if (_active.length > 1)
                    Wrap(
                      spacing: 4,
                      children: [
                        for (final cur in _active)
                          ChoiceChip(
                            label: Text(cur.code, style: const TextStyle(fontSize: 12)),
                            selected: cur == _currency,
                            onSelected: (_) => _switchCurrency(cur),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                ],
              ),
            ),
            // Huge amount
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        MoneyFormat.amount(amount),
                        style: TextStyle(
                          fontSize: 54,
                          height: 1.05,
                          fontWeight: FontWeight.w800,
                          color: amount.isZero ? AppColors.outline : color,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(_currency.shortName,
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: amount.isZero ? AppColors.outline : color)),
                    ],
                  ),
                  if (_newBalance != null)
                    Text(_newBalanceLine(_newBalance!),
                        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                ],
              ),
            ),
            // Selected notes strip
            SizedBox(
              height: 34,
              child: _notes.isEmpty || _keypad
                  ? const SizedBox.shrink()
                  : Row(
                      children: [
                        const SizedBox(width: 16),
                        Expanded(
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              for (final d in denoms)
                                for (var i = 0; i < (_notes[d.major] ?? 0); i++)
                                  Padding(
                                    padding: const EdgeInsetsDirectional.only(end: 4),
                                    child: GestureDetector(
                                      onTap: () => _remove(d.major),
                                      child: SizedBox(
                                          width: 50, child: BanknoteFace(d: d, compact: true)),
                                    ),
                                  ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _clear,
                          icon: const Icon(Icons.backspace_outlined, size: 18),
                          label: const Text(S.clear),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
            ),
            // Tabs: banknotes / keypad
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, icon: Icon(Icons.payments_rounded), label: Text(S.banknotes)),
                  ButtonSegment(value: true, icon: Icon(Icons.dialpad_rounded), label: Text(S.keypad)),
                ],
                selected: {_keypad},
                onSelectionChanged: (s) => setState(() {
                  _keypad = s.first;
                  if (_keypad && _notes.isNotEmpty && _typed.isEmpty) {
                    _typed = '${_amount.minor ~/ _pow10(_currency.minorUnits)}';
                    _notes.clear();
                  }
                }),
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _keypad ? _Keypad(onKey: _key) : _grid(denoms),
              ),
            ),
            // Confirm
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: SizedBox(
                height: 64,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: color),
                  onPressed: amount.isZero ? null : _next,
                  icon: const Icon(Icons.check_rounded, size: 30),
                  label: Text(TxLabels.of(context, type), style: const TextStyle(fontSize: 22)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grid(List<Denomination> denoms) {
    // Fill the available height: 3 rows × 2 cols, note aspect between 1.6 and 2.3
    // (real notes ≈ 2.2:1). Bigger notes = easier for low-literacy users.
    return LayoutBuilder(builder: (context, c) {
      const gap = 10.0;
      final rows = (denoms.length / 2).ceil();
      final cellW = (c.maxWidth - gap) / 2;
      var cellH = (c.maxHeight - gap * (rows - 1)) / rows;
      cellH = cellH.clamp(cellW / 2.3, cellW / 1.15);
      return Align(
        alignment: Alignment.topCenter,
        child: GridView.builder(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            childAspectRatio: cellW / cellH,
          ),
          itemCount: denoms.length,
          itemBuilder: (_, i) => BanknoteButton(
            d: denoms[i],
            count: _notes[denoms[i].major] ?? 0,
            onAdd: () => _add(denoms[i].major),
            onRemove: () => _remove(denoms[i].major),
          ),
        ),
      );
    });
  }

  

  String _balanceLine(Money? b) {
    if (b == null) return '';
    if (b.isZero) return '${S.currentBalance}: ${S.noDebt}';
    if (b.isNegative) return '${S.inCredit} الآن ${MoneyFormat.withName(b.abs)}';
    return '${S.currentBalance} ${MoneyFormat.withName(b)}';
  }

  String _newBalanceLine(Money b) {
    if (b.isZero) return 'يصير حسابه ${S.settled}';
    if (b.isNegative) return '${S.willBeInCredit} ${MoneyFormat.withName(b.abs)}';
    return '${S.newBalance} ${MoneyFormat.withName(b)}';
  }
}

class _Keypad extends StatelessWidget {
  final ValueChanged<String> onKey;
  const _Keypad({required this.onKey});

  static const _keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '000', '0', '⌫'];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.7,
      ),
      itemCount: _keys.length,
      itemBuilder: (_, i) {
        final k = _keys[i];
        return Material(
          color: k == '⌫' ? AppColors.debtContainer : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onKey(k),
            child: Center(
              child: k == '⌫'
                  ? const Icon(Icons.backspace_outlined, color: AppColors.debt, size: 28)
                  : Text(k,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
            ),
          ),
        );
      },
    );
  }
}
