// Dev helper (skipped by default): writes sample PDFs to /tmp/pdfout for visual QA.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil/core/docs/doc_data.dart';
import 'package:sijil/core/docs/doc_layout.dart';
import 'package:sijil/core/docs/doc_renderer.dart';
import 'package:sijil/core/docs/pdf_helpers.dart';
import 'package:sijil/core/ledger/ledger_models.dart';
import 'package:sijil/core/ledger/tx_type.dart';
import 'package:sijil/core/money/currency.dart';
import 'package:sijil/core/money/money.dart';

void main() {
  test('dump', () async {
    PdfHelpers.setFonts(
      tajawal: File('assets/fonts/Tajawal-Regular.ttf').readAsBytesSync(),
      tajawalBold: File('assets/fonts/Tajawal-Bold.ttf').readAsBytesSync(),
      amiri: File('assets/fonts/Amiri-Regular.ttf').readAsBytesSync(),
    );
    Money y(int n) => Money(n, Currency.yer);
    final now = DateTime(2026, 9, 9, 10, 45);
    const shop = DocShop(name: 'بقالة الأمل', address: 'صنعاء - شارع الستين', phone: '777123456', extraLine: 'سجل تجاري 12345');
    const cust = DocCustomer(name: 'أحمد صالح', phone: '771001233', idNumber: '01234567');
    var i = 0;
    LedgerTx tx(String t, int a, String? note, int daysAgo) => LedgerTx(
        id: 'i${i++}', shopId: 's', customerId: 'c', type: TxType.fromDb(t), amount: y(a), occurredAt: now.subtract(Duration(days: daysAgo)), recordedAt: now, recordedBy: 'u',
        noteText: note, customerNameSnap: 'أحمد', userNameSnap: 'صالح أحمد', overLimit: false, inLockedPeriod: false, deviceId: 'd', localSeq: i);
    final lines = <StatementLine>[]; var run = y(4000);
    for (final d in [('debit', 3000, 'سكر وأرز', 25), ('credit', 2000, null, 20), ('debit', 1500, 'حليب', 12), ('credit', 1000, null, 8), ('debit', 2500, 'دقيق وزيت', 2)]) {
      final t = tx(d.$1, d.$2, d.$3, d.$4); run = run + t.signedEffect; lines.add(StatementLine(t, run));
    }
    final st = Statement(customerId: 'c', currency: Currency.yer, from: now.subtract(const Duration(days: 30)), to: now, opening: y(4000), lines: lines, closing: run, totalDebit: y(7000), totalCredit: y(3000), totalAdjust: y(0));
    for (final p in DocPreset.values) {
      final l = DocLayout.preset(p).copyWith(footerText: 'البضاعة المباعة لا تُرد ولا تُستبدل');
      File('/tmp/pdfout/statement_detailed_${p.name}.pdf').writeAsBytesSync(await DocRenderer.statement(StatementDoc(shop: shop, customer: cust, sections: [st], detailed: true, issuedAt: now, watermarkTrial: p == DocPreset.compact), l.copyWith(showWorker: true)));
    }
    final l = DocLayout.preset(DocPreset.modern);
    File('/tmp/pdfout/statement.pdf').writeAsBytesSync(await DocRenderer.statement(StatementDoc(shop: shop, customer: cust, sections: [st], detailed: false, issuedAt: now), l));
    File('/tmp/pdfout/receipt.pdf').writeAsBytesSync(await DocRenderer.receipt(ReceiptDoc(shop: shop, customer: cust, receiptNo: '42', payment: lines[1].tx, balanceAfter: y(5000), receivedBy: 'صالح', issuedAt: now), DocLayout.preset(DocPreset.compact).copyWith(pageSize: 'A5')));
    File('/tmp/pdfout/receipt_thermal.pdf').writeAsBytesSync(await DocRenderer.receipt(ReceiptDoc(shop: shop, customer: cust, receiptNo: '42', payment: lines[1].tx, balanceAfter: y(5000), issuedAt: now), l, thermal: true));
    File('/tmp/pdfout/claim.pdf').writeAsBytesSync(await DocRenderer.claim(ClaimDoc(shop: shop, customer: cust, balances: {Currency.yer: run}, lastPaymentAt: now.subtract(const Duration(days: 40)), issuedAt: now), l));
    File('/tmp/pdfout/overdue.pdf').writeAsBytesSync(await DocRenderer.overdueReport(OverdueReportDoc(shop: shop, currency: Currency.yer, rows: [
      OverdueRow(name: 'أحمد صالح', phone: '777123456', balance: y(8000), lastPaymentAt: now.subtract(const Duration(days: 45)), daysOverdue: 45),
      OverdueRow(name: 'الحاج يحيى', phone: null, balance: y(15000), lastPaymentAt: null, daysOverdue: 120),
      OverdueRow(name: 'صالح ناصر', phone: '733000111', balance: y(15000), lastPaymentAt: now.subtract(const Duration(days: 200)), daysOverdue: 200),
    ], issuedAt: now), l));
    File('/tmp/pdfout/debt_ack.pdf').writeAsBytesSync(await DocRenderer.debtAck(DebtAckDoc(shop: shop, customer: cust, amount: run, payBy: now.add(const Duration(days: 30)), issuedAt: now), DocLayout.preset(DocPreset.classic).copyWith(signatures: ['customer','shop','witness1','witness2'])));
  }, skip: !Platform.environment.containsKey('DUMP_PDF'));
}
