import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/money/currency.dart';
import '../../data/app_services.dart';
import '../../data/repositories/currency_repository.dart';
import '../../data/session/session_provider.dart';
import '../../shared/l10n/ar_strings.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/utils/date_labels.dart';
import '../../shared/widgets/app_back_button.dart';

/// Currencies (phase 2). Client requirement (session 3):
/// - tapping the rate opens the keyboard directly — no separate "text mode";
/// - the currency is chosen from the list itself;
/// - an explicit back arrow, always.
/// Rates are display-only (R4); balances are never converted for storage.
class CurrenciesScreen extends StatefulWidget {
  const CurrenciesScreen({super.key});

  @override
  State<CurrenciesScreen> createState() => _CurrenciesScreenState();
}

class _CurrenciesScreenState extends State<CurrenciesScreen> {
  List<CurrencyState> _items = const [];
  final Map<String, FxRate?> _rates = {};
  final Map<String, TextEditingController> _ctrls = {};
  final Map<String, FocusNode> _focus = {};
  Currency _primary = Currency.yer;
  bool _loading = true;

  CurrencyRepository get _repo => context.read<AppServices>().currencies;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final items = await _repo.all();
    final primary = await _repo.primary();
    _rates.clear();
    for (final it in items) {
      if (it.currency == primary) continue;
      final r = await _repo.latest(it.currency, primary);
      _rates[it.currency.code] = r;
      final ctrl = _ctrls.putIfAbsent(
        it.currency.code,
        TextEditingController.new,
      );
      _focus.putIfAbsent(it.currency.code, FocusNode.new);
      if (!(_focus[it.currency.code]!.hasFocus)) {
        ctrl.text = r == null ? '' : _fmt(r.value);
      }
    }
    if (!mounted) return;
    setState(() {
      _items = items;
      _primary = primary;
      _loading = false;
    });
  }

  static String _fmt(double v) {
    var s = v.toStringAsFixed(4);
    s = s.replaceFirst(RegExp(r'\.?0+$'), '');
    return s;
  }

  Future<void> _saveRate(Currency c) async {
    final text = _ctrls[c.code]!.text;
    final existing = _rates[c.code];
    if (text.trim().isEmpty) return;
    if (existing != null && _fmt(existing.value) == text.trim()) return;
    if (CurrencyRepository.parseRate(text) == null) {
      _snack('سعر غير صحيح — أرقام فقط، مثل 530 أو 3.75', error: true);
      _ctrls[c.code]!.text = existing == null ? '' : _fmt(existing.value);
      return;
    }
    await _repo.setRate(
      c,
      _primary,
      text,
      byUserId: context.read<SessionProvider>().user?.id,
    );
    await _load();
    _snack(
      'تم حفظ السعر: 1 ${c.shortName} = ${_ctrls[c.code]!.text} ${_primary.shortName}',
    );
  }

  Future<void> _toggleActive(CurrencyState it, bool v) async {
    if (!v && it.isPrimary) {
      _snack('العملة الرئيسية لا يمكن إيقافها', error: true);
      return;
    }
    await _repo.setActive(it.currency.code, v);
    await _load();
  }

  Future<void> _makePrimary(CurrencyState it) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تغيير العملة الرئيسية'),
        content: Text(
          'ستُعرض الإجماليات في الرئيسية بـ${it.currency.nameAr}. '
          'أرصدة الزباين لا تتغير ولا تُحوَّل — كل عملة لها دفتر مستقل.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(S.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(S.confirm),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.setPrimary(it.currency.code);
    await _load();
  }

  void _snack(String m, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(m, style: const TextStyle(fontSize: 16)),
          backgroundColor: error ? AppColors.debt : AppColors.primary,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text(S.currencies),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _Hint(primary: _primary),
                  const SizedBox(height: 12),
                  for (final it in _items) ...[
                    _CurrencyCard(
                      state: it,
                      primary: _primary,
                      rate: _rates[it.currency.code],
                      controller: _ctrls[it.currency.code],
                      focusNode: _focus[it.currency.code],
                      onToggle: (v) => _toggleActive(it, v),
                      onMakePrimary: () => _makePrimary(it),
                      onRateSubmitted: () => _saveRate(it.currency),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final Currency primary;
  const _Hint({required this.primary});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accentContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'الرئيسية: ${primary.nameAr}. اضغط على السعر لكتابته مباشرة. '
              'السعر للعرض التقريبي (≈) فقط — كل عملة دفتر مستقل.',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.accent,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrencyCard extends StatelessWidget {
  final CurrencyState state;
  final Currency primary;
  final FxRate? rate;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<bool> onToggle;
  final VoidCallback onMakePrimary;
  final VoidCallback onRateSubmitted;
  const _CurrencyCard({
    required this.state,
    required this.primary,
    required this.rate,
    required this.controller,
    required this.focusNode,
    required this.onToggle,
    required this.onMakePrimary,
    required this.onRateSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final c = state.currency;
    final isPrimary = state.isPrimary;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: isPrimary
            ? Border.all(color: AppColors.primary, width: 2)
            : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isPrimary ? AppColors.primary : AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  c.symbol,
                  style: TextStyle(
                    fontSize: c.symbol.length > 2 ? 14 : 20,
                    fontWeight: FontWeight.w800,
                    color: isPrimary ? Colors.white : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.nameAr,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      isPrimary
                          ? 'العملة الرئيسية'
                          : (state.isActive ? 'مفعّلة' : 'غير مفعّلة'),
                      style: TextStyle(
                        fontSize: 12,
                        color: isPrimary
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isPrimary)
                const Icon(
                  Icons.star_rounded,
                  color: AppColors.accent,
                  size: 30,
                )
              else
                Switch(value: state.isActive, onChanged: onToggle),
            ],
          ),
          if (!isPrimary) ...[
            const SizedBox(height: 10),
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                if (state.isActive) {
                  focusNode?.requestFocus();
                } else {
                  onToggle(true);
                }
              },
              child: Row(
                children: [
                  Text(
                    '1 ${c.shortName} =',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      enabled: state.isActive,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩.]')),
                      ],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'اكتب السعر',
                        hintStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => onRateSubmitted(),
                      onTapOutside: (_) {
                        focusNode?.unfocus();
                        onRateSubmitted();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    primary.shortName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    rate == null
                        ? 'لم يُحدَّد سعر بعد'
                        : 'آخر تحديث: ${DateLabels.ago(rate!.setAt)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                if (state.isActive)
                  TextButton.icon(
                    onPressed: onMakePrimary,
                    icon: const Icon(Icons.star_outline_rounded, size: 20),
                    label: const Text('اجعلها رئيسية'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
