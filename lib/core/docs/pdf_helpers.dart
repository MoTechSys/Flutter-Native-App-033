import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'doc_layout.dart';

/// Shared PDF building blocks (docs/09 §1, lesson E1).
class PdfHelpers {
  PdfHelpers._();

  static pw.Font? _tajawal, _tajawalBold, _amiri;

  /// Fonts are embedded (docs/09 §1) — loaded once from assets.
  static Future<void> ensureFonts() async {
    if (_tajawal != null) return;
    _tajawal = pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Regular.ttf'));
    _tajawalBold = pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));
    _amiri = pw.Font.ttf(await rootBundle.load('assets/fonts/Amiri-Regular.ttf'));
  }

  /// For tests / tools without a Flutter binding.
  static void setFonts({required Uint8List tajawal, required Uint8List tajawalBold, required Uint8List amiri}) {
    _tajawal = pw.Font.ttf(ByteData.view(tajawal.buffer));
    _tajawalBold = pw.Font.ttf(ByteData.view(tajawalBold.buffer));
    _amiri = pw.Font.ttf(ByteData.view(amiri.buffer));
  }

  static pw.ThemeData theme(DocLayout l) {
    final base = l.preset == DocPreset.classic ? _amiri! : _tajawal!;
    final bold = l.preset == DocPreset.classic ? _amiri! : _tajawalBold!;
    return pw.ThemeData.withFont(base: base, bold: bold, italic: base, boldItalic: bold);
  }

  static PdfColor color(String hex) => PdfColor.fromHex(hex);

  static PdfPageFormat pageFormat(DocLayout l) => switch (l.pageSize) {
        'A5' => PdfPageFormat.a5,
        'roll80' => PdfPageFormat.roll80,
        _ => PdfPageFormat.a4,
      };

  /// Western → Arabic-Indic digits when the layout asks for it.
  static String digits(String s, DocLayout l) {
    if (!l.arabicDigits) return s;
    const ar = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return s.replaceAllMapped(RegExp(r'[0-9]'), (m) => ar[int.parse(m[0]!)]);
  }

  /// RTL table — E1: `pdf` does not reverse column order, so headers, rows,
  /// widths and alignments are all reversed here. Callers pass data in
  /// natural RTL reading order (first = rightmost).
  static pw.Widget rtlTable({
    required List<String> headers,
    required List<List<String>> rows,
    required List<double> flex,
    required DocLayout layout,
    List<pw.Alignment>? alignments,
    List<bool>? strike,
    PdfColor? accent,
  }) {
    final n = headers.length;
    final align = alignments ?? List.filled(n, pw.Alignment.centerRight);
    final widths = <int, pw.TableColumnWidth>{
      for (var i = 0; i < n; i++) i: pw.FlexColumnWidth(flex.reversed.toList()[i]),
    };
    final acc = accent ?? color(layout.accentColor);
    final fs = layout.tableFontSize;
    final headStyle = pw.TextStyle(fontSize: fs, fontWeight: pw.FontWeight.bold, color: PdfColors.white);
    final cellStyle = pw.TextStyle(fontSize: fs);

    pw.Widget cell(String t, pw.Alignment a, pw.TextStyle st, {bool strikeOut = false}) => pw.Container(
          alignment: a,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: pw.Text(
            digits(t, layout),
            style: strikeOut ? st.copyWith(decoration: pw.TextDecoration.lineThrough, color: PdfColors.grey600) : st,
            textDirection: pw.TextDirection.rtl,
          ),
        );

    return pw.Table(
      columnWidths: widths,
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: acc),
          children: [
            for (var i = n - 1; i >= 0; i--) cell(headers[i], pw.Alignment.center, headStyle),
          ],
        ),
        for (var r = 0; r < rows.length; r++)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: layout.zebra && r.isOdd ? PdfColors.grey100 : PdfColors.white,
            ),
            children: [
              for (var i = n - 1; i >= 0; i--)
                cell(rows[r][i], align[i], cellStyle, strikeOut: strike != null && strike[r]),
            ],
          ),
      ],
    );
  }

  /// Header block per layout (logo position, fields, divider).
  static pw.Widget header(DocLayout l, {
    required String shopName,
    String? address,
    String? phone,
    String? extraLine,
    Uint8List? logo,
    required String title,
  }) {
    final acc = color(l.accentColor);
    final lines = <pw.Widget>[];
    for (final f in l.headerFields) {
      final v = switch (f) {
        'shop_name' => shopName,
        'address' => address,
        'phone' => phone,
        'extra_line' => extraLine,
        _ => null,
      };
      if (v == null || v.isEmpty) continue;
      lines.add(pw.Text(
        digits(v, l),
        textDirection: pw.TextDirection.rtl,
        style: f == 'shop_name'
            ? pw.TextStyle(fontSize: l.titleFontSize, fontWeight: pw.FontWeight.bold, color: acc)
            : const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700),
      ));
    }
    final logoW = (l.logoShow && logo != null)
        ? pw.Image(pw.MemoryImage(logo), width: l.logoSize, height: l.logoSize, fit: pw.BoxFit.contain)
        : null;

    pw.Widget body;
    if (l.logoPosition == 'center' || logoW == null) {
      body = pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [if (logoW != null) logoW, if (logoW != null) pw.SizedBox(height: 4), ...lines],
      );
    } else {
      // RTL: 'right' logo = start of row.
      final children = [logoW, pw.SizedBox(width: 10), pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: lines))];
      body = pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: l.logoPosition == 'right' ? children : children.reversed.toList(),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        if (l.preset == DocPreset.modern)
          pw.Container(height: 6, color: acc, margin: const pw.EdgeInsets.only(bottom: 8)),
        body,
        pw.SizedBox(height: 6),
        pw.Text(title,
            textAlign: pw.TextAlign.center,
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(fontSize: l.titleFontSize - 2, fontWeight: pw.FontWeight.bold)),
        if (l.headerDivider) pw.Divider(color: acc, thickness: 0.8, height: 10),
      ],
    );
  }

  /// Footer: custom text, page X of Y, issued at, brand stamp.
  static pw.Widget footer(DocLayout l, pw.Context ctx, {required String issuedAtText}) {
    final small = const pw.TextStyle(fontSize: 8, color: PdfColors.grey600);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Divider(color: PdfColors.grey400, thickness: 0.4, height: 6),
        if (l.footerText.isNotEmpty)
          pw.Text(l.footerText, textAlign: pw.TextAlign.center, textDirection: pw.TextDirection.rtl, style: small),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            if (l.pageNumbers)
              pw.Text(digits('صفحة ${ctx.pageNumber} من ${ctx.pagesCount}', l), textDirection: pw.TextDirection.rtl, style: small)
            else
              pw.SizedBox(),
            if (l.issuedAt) pw.Text(digits(issuedAtText, l), textDirection: pw.TextDirection.rtl, style: small),
          ],
        ),
        if (l.brandStamp)
          pw.Text('صدر بواسطة سِجِل — دفتر الديون الرقمي',
              textAlign: pw.TextAlign.center, textDirection: pw.TextDirection.rtl, style: small.copyWith(color: PdfColors.grey500)),
      ],
    );
  }

  /// Signature boxes row.
  static pw.Widget signatures(DocLayout l, List<String> keys) {
    String label(String k) => switch (k) {
          'shop' => 'توقيع المحل',
          'customer' => 'توقيع الزبون',
          'witness1' => 'الشاهد الأول',
          'witness2' => 'الشاهد الثاني',
          'receiver' => 'المستلم',
          _ => k,
        };
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
      children: [
        for (final k in keys)
          pw.Column(children: [
            pw.Container(width: 130, height: 40, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.6)))),
            pw.SizedBox(height: 3),
            pw.Text(label(k), textDirection: pw.TextDirection.rtl, style: const pw.TextStyle(fontSize: 9)),
          ]),
      ],
    );
  }

  /// Diagonal "نسخة تجريبية" watermark for the unpaid version.
  static pw.Widget trialWatermark() => pw.Center(
        child: pw.Transform.rotate(
          angle: 0.6,
          child: pw.Opacity(
            opacity: 0.08,
            child: pw.Text('نسخة تجريبية — سِجِل',
                textDirection: pw.TextDirection.rtl,
                style: pw.TextStyle(fontSize: 54, fontWeight: pw.FontWeight.bold)),
          ),
        ),
      );

  /// Key/value line: "label: value" right-aligned.
  static pw.Widget kv(String label, String value, DocLayout l, {double size = 10, bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
        child: pw.Row(
          children: [
            pw.Text('$label: ', textDirection: pw.TextDirection.rtl, style: pw.TextStyle(fontSize: size, color: PdfColors.grey700)),
            pw.Expanded(
              child: pw.Text(digits(value, l),
                  textDirection: pw.TextDirection.rtl,
                  style: pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
            ),
          ],
        ),
      );
}
