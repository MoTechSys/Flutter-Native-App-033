import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/docs/doc_data.dart';
import '../../core/docs/doc_layout.dart';
import '../../core/docs/doc_renderer.dart';
import '../../core/docs/pdf_helpers.dart';
import '../../core/ledger/ledger_models.dart';
import '../../core/ledger/tx_type.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../data/app_services.dart';
import '../../data/repositories/document_repository.dart';
import '../../shared/l10n/ar_strings.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/app_back_button.dart';
import 'documents_screen.dart';

/// Header/footer editor with live A4 preview (docs/09 §5).
/// Tabs: الترويسة / التذييل / الجدول / عام. Preview re-renders (debounced)
/// with sample data so the user never sees JSON.
class TemplateEditorScreen extends StatefulWidget {
  final DocKind kind;
  final DocTemplate? existing;
  const TemplateEditorScreen({super.key, this.kind = DocKind.statementDetailed, this.existing});

  @override
  State<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends State<TemplateEditorScreen> with SingleTickerProviderStateMixin {
  late DocLayout _l;
  late DocKind _kind;
  Uint8List? _png;
  Timer? _debounce;
  bool _rendering = false;
  late final TabController _tabs = TabController(length: 4, vsync: this);
  final _footer = TextEditingController();

  DocumentRepository get _repo {
    final s = context.read<AppServices>();
    return DocumentRepository(s.db, s.ledger, deviceId: s.deviceId);
  }

  @override
  void initState() {
    super.initState();
    _kind = widget.existing?.kind ?? widget.kind;
    _l = widget.existing?.layout ?? DocLayout.preset(DocPreset.modern);
    _footer.text = _l.footerText;
    if (widget.existing == null) {
      _repo.defaultLayout(_kind).then((l) {
        if (mounted) {
          setState(() {
            _l = l;
            _footer.text = l.footerText;
          });
          _schedule();
        }
      });
    } else {
      _schedule();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabs.dispose();
    _footer.dispose();
    super.dispose();
  }

  void _update(DocLayout l) {
    setState(() => _l = l);
    _schedule();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _render);
  }

  Future<void> _render() async {
    if (_rendering) {
      _schedule();
      return;
    }
    _rendering = true;
    try {
      await PdfHelpers.ensureFonts();
      final shop = await _repo.shop();
      final bytes = await _sample(shop, _l);
      final png = await DocumentFlow.raster(bytes);
      if (mounted) setState(() => _png = png);
    } catch (e) {
      debugPrint('preview failed: $e');
    } finally {
      _rendering = false;
    }
  }

  /// Sample document (never touches real customers) so the editor works on day 1.
  Future<Uint8List> _sample(DocShop shop, DocLayout l) {
    final now = DateTime.now();
    final cust = const DocCustomer(name: 'أحمد صالح (مثال)', phone: '777123456', idNumber: '01234567');
    Money y(int n) => Money(n, Currency.yer);
    LedgerTx tx(int i, String type, int amt, String? note) => LedgerTx(
          id: 'x$i', shopId: 's', customerId: 'c', type: type == 'debit' ? TxType.debit : TxType.credit, amount: y(amt),
          occurredAt: now.subtract(Duration(days: 20 - i)), recordedAt: now.subtract(Duration(days: 20 - i)), recordedBy: 'u',
          noteText: note, customerNameSnap: cust.name, userNameSnap: 'صالح', overLimit: false, inLockedPeriod: false, deviceId: 'd', localSeq: i,
        );
    final lines = <StatementLine>[];
    var run = y(4000);
    final data = [('debit', 3000, 'سكر وأرز'), ('credit', 2000, null), ('debit', 1500, 'حليب'), ('credit', 1000, null), ('debit', 2500, 'دقيق')];
    for (var i = 0; i < data.length; i++) {
      final t = tx(i, data[i].$1, data[i].$2, data[i].$3);
      run = run + t.signedEffect;
      lines.add(StatementLine(t, run));
    }
    final st = Statement(customerId: 'c', currency: Currency.yer, from: now.subtract(const Duration(days: 30)), to: now, opening: y(4000), lines: lines, closing: run, totalDebit: y(7000), totalCredit: y(3000), totalAdjust: y(0));
    switch (_kind) {
      case DocKind.statement:
      case DocKind.statementDetailed:
        return DocRenderer.statement(StatementDoc(shop: shop, customer: cust, sections: [st], detailed: _kind == DocKind.statementDetailed, issuedAt: now), l);
      case DocKind.receipt:
        return DocRenderer.receipt(ReceiptDoc(shop: shop, customer: cust, receiptNo: '42', payment: lines[1].tx, balanceAfter: y(5000), receivedBy: 'صالح', issuedAt: now), l);
      case DocKind.claim:
        return DocRenderer.claim(ClaimDoc(shop: shop, customer: cust, balances: {Currency.yer: run}, lastPaymentAt: now.subtract(const Duration(days: 40)), issuedAt: now), l);
      case DocKind.overdueReport:
        return DocRenderer.overdueReport(OverdueReportDoc(shop: shop, currency: Currency.yer, rows: [
          OverdueRow(name: 'أحمد صالح', phone: '777123456', balance: y(8000), lastPaymentAt: now.subtract(const Duration(days: 45)), daysOverdue: 45),
          OverdueRow(name: 'الحاج يحيى', phone: null, balance: y(15000), lastPaymentAt: null, daysOverdue: 120),
        ], issuedAt: now), l);
      case DocKind.debtAck:
        return DocRenderer.debtAck(DebtAckDoc(shop: shop, customer: cust, amount: run, payBy: now.add(const Duration(days: 30)), issuedAt: now), l);
    }
  }

  Future<void> _save({required bool asDefault}) async {
    final nameCtrl = TextEditingController(text: widget.existing?.nameAr ?? '${_kind.titleAr} — ${_presetAr(_l.preset)}');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(asDefault ? 'حفظ وتعيين كافتراضي' : 'حفظ كقالب'),
        content: TextField(controller: nameCtrl, autofocus: true, decoration: const InputDecoration(labelText: 'اسم القالب')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text(S.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, nameCtrl.text), child: const Text(S.save)),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    await _repo.saveTemplate(id: widget.existing?.id, nameAr: name, kind: _kind, layout: _l.copyWith(footerText: _footer.text), makeDefault: asDefault);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ القالب')));
      Navigator.pop(context, true);
    }
  }

  static String _presetAr(DocPreset p) => switch (p) { DocPreset.classic => 'كلاسيكي', DocPreset.modern => 'حديث', DocPreset.compact => 'مضغوط' };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('قالب المستند'),
        actions: [
          PopupMenuButton<String>(
            iconSize: 28,
            onSelected: (v) {
              if (v == 'reset') _update(DocLayout.preset(_l.preset));
              if (v == 'save') _save(asDefault: false);
              if (v == 'default') _save(asDefault: true);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'save', child: Text('حفظ كقالب')),
              PopupMenuItem(value: 'default', child: Text('حفظ وتعيين كافتراضي')),
              PopupMenuItem(value: 'reset', child: Text('استعادة الافتراضي')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Live preview
            Expanded(
              flex: 5,
              child: Container(
                color: AppColors.textSecondary.withValues(alpha: 0.15),
                padding: const EdgeInsets.all(10),
                child: Center(
                  child: _png == null
                      ? const CircularProgressIndicator()
                      : Container(
                          decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 10)]),
                          child: Image.memory(_png!, fit: BoxFit.contain, gaplessPlayback: true),
                        ),
                ),
              ),
            ),
            // Kind + preset row
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<DocKind>(
                      initialValue: _kind,
                      isDense: true,
                      decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      items: [for (final k in DocKind.values) DropdownMenuItem(value: k, child: Text(k.titleAr, style: const TextStyle(fontSize: 14)))],
                      onChanged: widget.existing != null ? null : (k) {
                        if (k == null) return;
                        setState(() => _kind = k);
                        _schedule();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SegmentedButton<DocPreset>(
                    segments: const [
                      ButtonSegment(value: DocPreset.classic, label: Text('كلاسيكي')),
                      ButtonSegment(value: DocPreset.modern, label: Text('حديث')),
                      ButtonSegment(value: DocPreset.compact, label: Text('مضغوط')),
                    ],
                    selected: {_l.preset},
                    showSelectedIcon: false,
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                    onSelectionChanged: (s) => _update(DocLayout.preset(s.first).copyWith(footerText: _footer.text, numerals: _l.numerals)),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabs,
              tabs: const [Tab(text: 'الترويسة'), Tab(text: 'التذييل'), Tab(text: 'الجدول'), Tab(text: 'عام')],
            ),
            Expanded(
              flex: 4,
              child: TabBarView(
                controller: _tabs,
                children: [_headerTab(), _footerTab(), _tableTab(), _generalTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerTab() => ListView(padding: const EdgeInsets.all(8), children: [
        SwitchListTile(dense: true, title: const Text('إظهار الشعار'), value: _l.logoShow, onChanged: (v) => _update(_l.copyWith(logoShow: v))),
        ListTile(
          dense: true,
          title: const Text('موضع الشعار'),
          trailing: SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'right', label: Text('يمين')), ButtonSegment(value: 'center', label: Text('وسط')), ButtonSegment(value: 'left', label: Text('يسار'))],
            selected: {_l.logoPosition},
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            onSelectionChanged: (s) => _update(_l.copyWith(logoPosition: s.first)),
          ),
        ),
        _slider('حجم الشعار', _l.logoSize, 32, 96, (v) => _update(_l.copyWith(logoSize: v))),
        _slider('حجم العنوان', _l.titleFontSize, 12, 24, (v) => _update(_l.copyWith(titleFontSize: v))),
        for (final f in const ['shop_name', 'address', 'phone', 'extra_line'])
          CheckboxListTile(
            dense: true,
            title: Text(switch (f) { 'shop_name' => 'اسم المحل', 'address' => 'العنوان', 'phone' => 'الهاتف', _ => 'سطر إضافي (سجل تجاري…)' }),
            value: _l.headerFields.contains(f),
            onChanged: (v) {
              final list = List<String>.from(_l.headerFields);
              v == true ? (list.contains(f) ? null : list.add(f)) : list.remove(f);
              _update(_l.copyWith(headerFields: list));
            },
          ),
        SwitchListTile(dense: true, title: const Text('خط فاصل تحت الترويسة'), value: _l.headerDivider, onChanged: (v) => _update(_l.copyWith(headerDivider: v))),
        ListTile(
          dense: true,
          title: const Text('اللون'),
          trailing: Wrap(spacing: 6, children: [
            for (final c in const ['#0B5D48', '#1F3A5F', '#8A6200', '#6A1B9A', '#222222', '#B71C1C'])
              GestureDetector(
                onTap: () => _update(_l.copyWith(accentColor: c)),
                child: Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(color: Color(int.parse('FF${c.substring(1)}', radix: 16)), shape: BoxShape.circle,
                      border: Border.all(color: _l.accentColor == c ? Colors.black : Colors.transparent, width: 2)),
                ),
              ),
          ]),
        ),
      ]);

  Widget _footerTab() => ListView(padding: const EdgeInsets.all(8), children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TextField(
            controller: _footer,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'نص التذييل', hintText: 'مثال: البضاعة المباعة لا تُرد ولا تُستبدل'),
            onChanged: (v) => _update(_l.copyWith(footerText: v)),
          ),
        ),
        SwitchListTile(dense: true, title: const Text('ترقيم الصفحات'), value: _l.pageNumbers, onChanged: (v) => _update(_l.copyWith(pageNumbers: v))),
        SwitchListTile(dense: true, title: const Text('تاريخ الإصدار'), value: _l.issuedAt, onChanged: (v) => _update(_l.copyWith(issuedAt: v))),
        SwitchListTile(dense: true, title: const Text('بصمة "صدر بواسطة سِجِل"'), value: _l.brandStamp, onChanged: (v) => _update(_l.copyWith(brandStamp: v))),
      ]);

  Widget _tableTab() => ListView(padding: const EdgeInsets.all(8), children: [
        SwitchListTile(dense: true, title: const Text('عمود "سجّلها" (العامل)'), value: _l.showWorker, onChanged: (v) => _update(_l.copyWith(showWorker: v))),
        SwitchListTile(dense: true, title: const Text('عمود الوقت'), value: _l.showTime, onChanged: (v) => _update(_l.copyWith(showTime: v))),
        SwitchListTile(dense: true, title: const Text('إظهار المُلغاة مشطوبة'), value: _l.showReversed, onChanged: (v) => _update(_l.copyWith(showReversed: v))),
        SwitchListTile(dense: true, title: const Text('تظليل الصفوف بالتناوب'), value: _l.zebra, onChanged: (v) => _update(_l.copyWith(zebra: v))),
        _slider('حجم خط الجدول', _l.tableFontSize, 8, 12, (v) => _update(_l.copyWith(tableFontSize: v))),
      ]);

  Widget _generalTab() => ListView(padding: const EdgeInsets.all(8), children: [
        ListTile(
          dense: true,
          title: const Text('الأرقام'),
          trailing: SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'western', label: Text('123')), ButtonSegment(value: 'arabic', label: Text('١٢٣'))],
            selected: {_l.numerals},
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            onSelectionChanged: (s) => _update(_l.copyWith(numerals: s.first)),
          ),
        ),
        _slider('الهوامش', _l.margin, 18, 48, (v) => _update(_l.copyWith(margin: v))),
        const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 0), child: Text('التواقيع', style: TextStyle(fontWeight: FontWeight.w700))),
        for (final s in const ['shop', 'customer', 'witness1', 'witness2'])
          CheckboxListTile(
            dense: true,
            title: Text(switch (s) { 'shop' => 'المحل', 'customer' => 'الزبون', 'witness1' => 'شاهد 1', _ => 'شاهد 2' }),
            value: _l.signatures.contains(s),
            onChanged: (v) {
              final list = List<String>.from(_l.signatures);
              v == true ? (list.contains(s) ? null : list.add(s)) : list.remove(s);
              _update(_l.copyWith(signatures: list));
            },
          ),
      ]);

  Widget _slider(String label, double v, double min, double max, ValueChanged<double> onChanged) => ListTile(
        dense: true,
        title: Text(label),
        subtitle: Slider(value: v.clamp(min, max), min: min, max: max, onChanged: onChanged),
        trailing: Text(v.round().toString()),
      );
}

