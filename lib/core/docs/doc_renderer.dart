import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../ledger/ledger_models.dart';
import '../ledger/tx_type.dart';
import '../money/arabic_words.dart';
import '../money/money.dart';
import '../money/money_format.dart';
import 'doc_data.dart';
import 'doc_layout.dart';
import 'pdf_helpers.dart';

/// Renders the six document kinds (docs/09 §2) with any [DocLayout].
/// Pure: no DB, no IO. Money arithmetic already done by LedgerService.
class DocRenderer {
  DocRenderer._();

  static final _date = DateFormat('yyyy/MM/dd');
  static final _dateTime = DateFormat('yyyy/MM/dd HH:mm');

  static String _d(DateTime d) => _date.format(d.toLocal());
  static String _dt(DateTime d) => _dateTime.format(d.toLocal());
  static String _m(Money m) => MoneyFormat.amount(m);
  static String _mn(Money m) => MoneyFormat.withName(m);
  static String _issued(DateTime d) => 'تاريخ الإصدار: ${_dt(d)}';

  static pw.Document _doc(DocLayout l) => pw.Document(theme: PdfHelpers.theme(l), title: 'سِجِل');

  static pw.MultiPage _page(
    DocLayout l, {
    required pw.Widget header,
    required DateTime issuedAt,
    required List<pw.Widget> body,
    bool watermark = false,
    PdfPageFormat? format,
  }) =>
      pw.MultiPage(
        pageFormat: format ?? PdfHelpers.pageFormat(l),
        margin: pw.EdgeInsets.all(l.margin),
        textDirection: pw.TextDirection.rtl,
        header: (_) => header,
        footer: (ctx) => PdfHelpers.footer(l, ctx, issuedAtText: _issued(issuedAt)),
        build: (_) => [
          if (watermark) PdfHelpers.trialWatermark(),
          ...body,
        ],
      );

  // ---------------------------------------------------------------------------
  // statement / statement_detailed
  // ---------------------------------------------------------------------------
  static Future<Uint8List> statement(StatementDoc d, DocLayout l) async {
    final doc = _doc(l);
    final kind = d.detailed ? DocKind.statementDetailed : DocKind.statement;
    final body = <pw.Widget>[
      _customerBlock(d.customer, l, extra: [
        if (d.sections.isNotEmpty)
          PdfHelpers.kv('الفترة', '${_d(d.sections.first.from)} — ${_d(d.sections.first.to)}', l),
      ]),
      pw.SizedBox(height: 8),
    ];
    for (final s in d.sections) {
      if (d.sections.length > 1) {
        body.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
          child: pw.Text('عملة: ${s.currency.nameAr}',
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfHelpers.color(l.accentColor))),
        ));
      }
      body.add(_summaryTable(s, l));
      if (d.detailed) {
        body.add(pw.SizedBox(height: 8));
        body.add(_linesTable(s, l));
      }
      body.add(pw.SizedBox(height: 6));
      body.add(_closingLine(s, l));
      body.add(pw.SizedBox(height: 10));
    }
    body.add(pw.SizedBox(height: 18));
    body.add(PdfHelpers.signatures(l, l.signatures));

    doc.addPage(_page(
      l,
      header: _header(d.shop, l, kind.titleAr),
      issuedAt: d.issuedAt,
      body: body,
      watermark: d.watermarkTrial,
    ));
    return doc.save();
  }

  static pw.Widget _summaryTable(Statement s, DocLayout l) {
    final rows = <List<String>>[
      ['الرصيد الافتتاحي', _m(s.opening), _sideWord(s.opening)],
      ['إجمالي ما أُخذ (عليه)', _m(s.totalDebit), ''],
      ['إجمالي ما دُفع (له)', _m(s.totalCredit), ''],
      if (!s.totalAdjust.isZero) ['تسويات', _m(s.totalAdjust), s.totalAdjust.isNegative ? 'خصم' : 'زيادة'],
      ['الرصيد الختامي', _m(s.closing), _sideWord(s.closing)],
    ];
    return PdfHelpers.rtlTable(
      headers: const ['البيان', 'المبلغ', 'الحالة'],
      rows: rows,
      flex: const [3, 2, 1.2],
      layout: l,
      alignments: const [pw.Alignment.centerRight, pw.Alignment.centerLeft, pw.Alignment.center],
    );
  }

  static String _sideWord(Money m) => m.isZero ? 'مسدَّد' : (m.isNegative ? 'له' : 'عليه');

  static pw.Widget _linesTable(Statement s, DocLayout l) {
    final cols = <String>['date', if (l.showTime) 'time', 'description', if (l.showWorker) 'worker', 'debit', 'credit', 'running_balance'];
    String head(String c) => switch (c) {
          'date' => 'التاريخ',
          'time' => 'الوقت',
          'description' => 'البيان',
          'worker' => 'سجّلها',
          'debit' => 'عليه',
          'credit' => 'له',
          'running_balance' => 'الرصيد',
          _ => c,
        };
    double flex(String c) => switch (c) {
          'date' => 1.5,
          'time' => 1,
          'description' => 3,
          'worker' => 1.3,
          _ => 1.4,
        };
    final rows = <List<String>>[];
    final strike = <bool>[];
    rows.add([for (final c in cols) c == 'description' ? 'رصيد سابق' : (c == 'running_balance' ? _m(s.opening) : '')]);
    strike.add(false);
    for (final line in s.lines) {
      final tx = line.tx;
      final dead = tx.isReversed || tx.isReversal;
      if (dead && !l.showReversed) continue;
      final eff = tx.signedEffect;
      rows.add([
        for (final c in cols)
          switch (c) {
            'date' => _d(tx.occurredAt),
            'time' => DateFormat('HH:mm').format(tx.occurredAt.toLocal()),
            'description' => _desc(tx),
            'worker' => tx.userNameSnap,
            'debit' => eff.isNegative ? '' : _m(tx.amount),
            'credit' => eff.isNegative ? _m(tx.amount) : '',
            'running_balance' => _m(line.runningBalance),
            _ => '',
          }
      ]);
      strike.add(dead);
    }
    return PdfHelpers.rtlTable(
      headers: cols.map(head).toList(),
      rows: rows,
      flex: cols.map(flex).toList(),
      layout: l,
      strike: strike,
      alignments: [for (final c in cols) c == 'description' ? pw.Alignment.centerRight : pw.Alignment.center],
    );
  }

  static String _desc(LedgerTx tx) {
    final base = switch (tx.type) {
      TxType.debit => 'أخذ بضاعة',
      TxType.credit => 'دفعة',
      TxType.adjustDown => 'تسوية (خصم)',
      TxType.adjustUp => 'تسوية (زيادة)',
      TxType.opening => 'رصيد سابق',
    };
    final note = tx.noteText;
    final rev = tx.isReversal ? ' — قيد عكسي' : (tx.isReversed ? ' — مُلغاة' : '');
    return note == null || note.isEmpty ? '$base$rev' : '$base: $note$rev';
  }

  static pw.Widget _closingLine(Statement s, DocLayout l) {
    final c = s.closing;
    final text = c.isZero
        ? 'الحساب مسدَّد بالكامل.'
        : c.isNegative
            ? 'الرصيد لصالح الزبون: ${_mn(c.abs)} (${ArabicWords.money(c.abs)})'
            : 'المتبقي على الزبون: ${_mn(c)} (${ArabicWords.money(c)})';
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfHelpers.color(l.accentColor), width: 0.8),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(PdfHelpers.digits(text, l),
          textDirection: pw.TextDirection.rtl,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
    );
  }

  // ---------------------------------------------------------------------------
  // receipt (half A4 or 80mm)
  // ---------------------------------------------------------------------------
  static Future<Uint8List> receipt(ReceiptDoc d, DocLayout l, {bool thermal = false}) async {
    final doc = _doc(l);
    final amount = d.payment.amount;
    final format = thermal ? PdfPageFormat.roll80 : PdfPageFormat.a5;
    final body = <pw.Widget>[
      pw.SizedBox(height: 6),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(PdfHelpers.digits('رقم السند: ${d.receiptNo}', l), textDirection: pw.TextDirection.rtl, style: const pw.TextStyle(fontSize: 10)),
        pw.Text(PdfHelpers.digits('التاريخ: ${_dt(d.payment.occurredAt)}', l), textDirection: pw.TextDirection.rtl, style: const pw.TextStyle(fontSize: 10)),
      ]),
      pw.SizedBox(height: 10),
      PdfHelpers.kv('استلمنا من', d.customer.name, l, size: 12, bold: true),
      PdfHelpers.kv('مبلغاً وقدره', _mn(amount), l, size: 14, bold: true),
      PdfHelpers.kv('فقط', '${ArabicWords.money(amount)} لا غير', l, size: 10),
      PdfHelpers.kv('وذلك عن', d.payment.noteText?.isNotEmpty == true ? d.payment.noteText! : 'سداد من الحساب', l),
      pw.SizedBox(height: 6),
      pw.Container(
        padding: const pw.EdgeInsets.all(6),
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.6), borderRadius: pw.BorderRadius.circular(4)),
        child: PdfHelpers.kv('الرصيد بعد الدفع', d.balanceAfter.isZero ? 'مسدَّد' : '${_mn(d.balanceAfter.abs)} ${_sideWord(d.balanceAfter)}', l, size: 11, bold: true),
      ),
      pw.SizedBox(height: 16),
      PdfHelpers.signatures(l, ['receiver', 'customer']),
      if (d.receivedBy != null) ...[
        pw.SizedBox(height: 4),
        pw.Text('المستلم: ${d.receivedBy}', textDirection: pw.TextDirection.rtl, style: const pw.TextStyle(fontSize: 9)),
      ],
    ];
    if (thermal) {
      // roll80 has infinite height → single Page with a fixed tall format
      // (printer cuts at content end).
      final tl = l.copyWith(margin: 8, logoSize: 32, tableFontSize: 9, titleFontSize: 12, accentColor: '#000000', brandStamp: false);
      final fmt = PdfPageFormat(PdfPageFormat.roll80.width, 120 * PdfPageFormat.mm, marginAll: 8);
      doc.addPage(pw.Page(
        pageFormat: fmt,
        textDirection: pw.TextDirection.rtl,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _header(d.shop, tl, DocKind.receipt.titleAr),
            ...body,
            pw.Spacer(),
            PdfHelpers.footer(tl, ctx, issuedAtText: _issued(d.issuedAt)),
          ],
        ),
      ));
      return doc.save();
    }
    doc.addPage(_page(
      l,
      format: format,
      header: _header(d.shop, l, DocKind.receipt.titleAr),
      issuedAt: d.issuedAt,
      body: body,
      watermark: d.watermarkTrial,
    ));
    return doc.save();
  }

  // ---------------------------------------------------------------------------
  // claim
  // ---------------------------------------------------------------------------
  static Future<Uint8List> claim(ClaimDoc d, DocLayout l) async {
    final doc = _doc(l);
    final rows = [for (final e in d.balances.entries) if (e.value.isPositive) [e.key.nameAr, _m(e.value), ArabicWords.money(e.value)]];
    final body = <pw.Widget>[
      _customerBlock(d.customer, l),
      pw.SizedBox(height: 10),
      pw.Text(
        PdfHelpers.digits(
            'السلام عليكم ورحمة الله،\n'
            'نفيدكم بأن رصيدكم المستحق لدى ${d.shop.name} حتى تاريخ ${_d(d.issuedAt)} هو كما في الجدول أدناه'
            '${d.lastPaymentAt == null ? '، ولم تُسجَّل أي دفعة حتى الآن.' : '، وكانت آخر دفعة بتاريخ ${_d(d.lastPaymentAt!)}.'}\n'
            'نأمل التكرم بالسداد خلال ${d.payWithinDays} أيام من تاريخه، ولكم جزيل الشكر.',
            l),
        textDirection: pw.TextDirection.rtl,
        style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
      ),
      pw.SizedBox(height: 10),
      PdfHelpers.rtlTable(
        headers: const ['العملة', 'المبلغ', 'كتابةً'],
        rows: rows,
        flex: const [1.5, 1.5, 3.5],
        layout: l,
      ),
      pw.SizedBox(height: 14),
      if (d.shop.phone != null) PdfHelpers.kv('للتواصل', d.shop.phone!, l),
      pw.SizedBox(height: 24),
      PdfHelpers.signatures(l, const ['shop']),
    ];
    doc.addPage(_page(l, header: _header(d.shop, l, DocKind.claim.titleAr), issuedAt: d.issuedAt, body: body, watermark: d.watermarkTrial));
    return doc.save();
  }

  // ---------------------------------------------------------------------------
  // overdue_report
  // ---------------------------------------------------------------------------
  static Future<Uint8List> overdueReport(OverdueReportDoc d, DocLayout l) async {
    final doc = _doc(l);
    var total = Money.zero(d.currency);
    for (final r in d.rows) {
      total = total + r.balance;
    }
    String bucket(int days) => days < 60 ? '30+' : (days < 90 ? '60+' : (days < 180 ? '90+' : '180+'));
    final rows = [
      for (var i = 0; i < d.rows.length; i++)
        [
          '${i + 1}',
          d.rows[i].name,
          d.rows[i].phone ?? '—',
          _m(d.rows[i].balance),
          d.rows[i].lastPaymentAt == null ? 'لا دفعات' : _d(d.rows[i].lastPaymentAt!),
          '${d.rows[i].daysOverdue}',
          bucket(d.rows[i].daysOverdue),
        ],
    ];
    final body = <pw.Widget>[
      PdfHelpers.kv('العملة', d.currency.nameAr, l),
      PdfHelpers.kv('عدد المتأخرين', '${d.rows.length}', l),
      PdfHelpers.kv('الإجمالي', _mn(total), l, bold: true, size: 12),
      pw.SizedBox(height: 8),
      PdfHelpers.rtlTable(
        headers: const ['#', 'الزبون', 'الهاتف', 'الرصيد', 'آخر دفعة', 'أيام', 'الفئة'],
        rows: rows,
        flex: const [0.5, 2.5, 1.8, 1.6, 1.6, 0.8, 0.9],
        layout: l,
        alignments: const [
          pw.Alignment.center, pw.Alignment.centerRight, pw.Alignment.center, pw.Alignment.centerLeft,
          pw.Alignment.center, pw.Alignment.center, pw.Alignment.center,
        ],
      ),
    ];
    doc.addPage(_page(l, header: _header(d.shop, l, DocKind.overdueReport.titleAr), issuedAt: d.issuedAt, body: body, watermark: d.watermarkTrial));
    return doc.save();
  }

  // ---------------------------------------------------------------------------
  // debt_ack
  // ---------------------------------------------------------------------------
  static Future<Uint8List> debtAck(DebtAckDoc d, DocLayout l) async {
    final doc = _doc(l);
    final blank = '..........................';
    final body = <pw.Widget>[
      pw.SizedBox(height: 10),
      pw.Text(
        PdfHelpers.digits(
            'أقر أنا الموقّع أدناه: ${d.customer.name}\n'
            'بطاقة شخصية رقم: ${d.customer.idNumber ?? blank}\n\n'
            'بأن في ذمتي لصالح ${d.shop.name} مبلغاً وقدره ${_mn(d.amount)} '
            '(${ArabicWords.money(d.amount)} لا غير)، وذلك قيمة بضاعة استلمتها بالدين.\n\n'
            'وأتعهد بسداد المبلغ كاملاً ${d.payBy == null ? 'عند الطلب' : 'في موعد أقصاه ${_d(d.payBy!)}'}، '
            'وهذا إقرار منّي بذلك وأنا بكامل أهليتي المعتبرة شرعاً وقانوناً.',
            l),
        textDirection: pw.TextDirection.rtl,
        style: const pw.TextStyle(fontSize: 12, lineSpacing: 5),
      ),
      pw.SizedBox(height: 16),
      PdfHelpers.kv('التاريخ', _d(d.issuedAt), l, size: 11),
      pw.SizedBox(height: 30),
      PdfHelpers.signatures(l, const ['customer', 'shop']),
      pw.SizedBox(height: 26),
      PdfHelpers.signatures(l, const ['witness1', 'witness2']),
    ];
    final classic = l.copyWith(preset: DocPreset.classic, zebra: false);
    doc.addPage(_page(classic, header: _header(d.shop, classic, DocKind.debtAck.titleAr), issuedAt: d.issuedAt, body: body, watermark: d.watermarkTrial));
    return doc.save();
  }

  // ---------------------------------------------------------------------------
  static pw.Widget _header(DocShop s, DocLayout l, String title) => PdfHelpers.header(
        l,
        shopName: s.name,
        address: s.address,
        phone: s.phone,
        extraLine: s.extraLine,
        logo: s.logoBytes,
        title: title,
      );

  static pw.Widget _customerBlock(DocCustomer c, DocLayout l, {List<pw.Widget> extra = const []}) => pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Column(children: [
          PdfHelpers.kv('الزبون', c.name, l, size: 12, bold: true),
          if (c.phone != null) PdfHelpers.kv('الهاتف', c.phone!, l),
          ...extra,
        ]),
      );
}
