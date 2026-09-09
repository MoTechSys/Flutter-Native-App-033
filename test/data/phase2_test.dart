import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sijil/core/activation/activation.dart';
import 'package:sijil/core/docs/doc_data.dart';
import 'package:sijil/core/docs/doc_layout.dart';
import 'package:sijil/core/docs/doc_renderer.dart';
import 'package:sijil/core/docs/pdf_helpers.dart';
import 'package:sijil/core/ledger/ledger_models.dart';
import 'package:sijil/core/ledger/tx_type.dart';
import 'package:sijil/core/money/currency.dart';
import 'package:sijil/core/money/money.dart';
import 'package:sijil/data/backup/backup_service.dart';
import 'package:sijil/data/repositories/currency_repository.dart';
import 'package:sijil/data/repositories/customer_repository.dart';
import 'package:sijil/data/repositories/overdue_repository.dart';
import 'package:sijil/data/repositories/reports_repository.dart';
import 'package:sijil/data/repositories/settings_repository.dart';
import 'package:sijil/shared/services/reminder_service.dart';

import '../ledger/test_helpers.dart';

Money y(int n) => Money(n, Currency.yer);

void main() {
  late TestEnv env;
  late CustomerRepository customers;

  setUp(() async {
    env = await TestEnv.create();
    customers = CustomerRepository(env.db, shopId: shopId, deviceId: deviceA);
  });
  tearDown(() => env.close());

  group('CurrencyRepository', () {
    test('parseRate exact fractions, arabic digits, rejects junk', () {
      expect(CurrencyRepository.parseRate('530'), (530, 1));
      expect(CurrencyRepository.parseRate('3.75'), (15, 4));
      expect(CurrencyRepository.parseRate('0.0019'), (19, 10000));
      expect(CurrencyRepository.parseRate('٥٣٠'), (530, 1));
      expect(CurrencyRepository.parseRate('1,530'), (1530, 1));
      expect(CurrencyRepository.parseRate('0'), isNull);
      expect(CurrencyRepository.parseRate('abc'), isNull);
      expect(CurrencyRepository.parseRate('1.23456'), isNull);
    });

    test('activate / primary / approx conversion (display only)', () async {
      final repo = CurrencyRepository(env.db);
      await repo.setActive('SAR', true);
      expect((await repo.active()).map((c) => c.code), containsAll(['YER', 'SAR']));
      expect(() => repo.setActive('YER', false), throwsStateError);
      await repo.setRate(Currency.sar, Currency.yer, '140');
      final approx = await repo.approx(Money(1000, Currency.sar), Currency.yer); // 10.00 SAR
      expect(approx, y(1400));
      // inverse via stored rate
      final back = await repo.approx(y(1400), Currency.sar);
      expect(back, Money(1000, Currency.sar));
      await repo.setPrimary('SAR');
      expect((await repo.primary()).code, 'SAR');
      expect((await repo.all()).firstWhere((c) => c.currency.code == 'SAR').isActive, isTrue);
    });
  });

  group('SettingsRepository', () {
    test('defaults, set/get, typed coercion, persistence', () async {
      final st = SettingsRepository(env.db);
      await st.load();
      expect(st.labelTook, 'أخذ مني');
      expect(st.overdueDays, 30);
      expect(st.get<double>(SettingsRepository.kFontScale), 1.0);
      await st.set(SettingsRepository.kLabelTook, 'شرى بالدين');
      await st.set(SettingsRepository.kFontScale, 1.2);
      await st.set(SettingsRepository.kOverdueDays, 45);
      final st2 = SettingsRepository(env.db);
      await st2.load();
      expect(st2.labelTook, 'شرى بالدين');
      expect(st2.fontScale, 1.2);
      expect(st2.overdueDays, 45);
      expect(st2.get<int?>(SettingsRepository.kInstalledAt), isNotNull);
    });

    test('locked_before written by settings is honoured by the ledger (R7)', () async {
      final st = SettingsRepository(env.db);
      await st.load();
      final c = await customers.add(name: 'أحمد', byUserId: owner.userId);
      await st.set(SettingsRepository.kLockedBefore, DateTime.utc(2026, 9, 1).millisecondsSinceEpoch);
      expect(
        () => env.ledger.record(
            NewTransaction(customerId: c.id, type: TxType.debit, amount: y(100), occurredAt: DateTime.utc(2026, 8, 15)), worker),
        throwsA(isA<Object>()),
      );
    });
  });

  group('OverdueRepository', () {
    test('buckets and promise', () async {
      expect(OverdueRepository.bucketFor(31), AgingBucket.d30);
      expect(OverdueRepository.bucketFor(75), AgingBucket.d60);
      expect(OverdueRepository.bucketFor(100), AgingBucket.d90);
      expect(OverdueRepository.bucketFor(200), AgingBucket.d90plus);

      final a = await customers.add(name: 'أحمد', byUserId: owner.userId);
      final b = await customers.add(name: 'بدر', byUserId: owner.userId);
      final now = DateTime.now().toUtc();
      await env.ledger.record(NewTransaction(customerId: a.id, type: TxType.debit, amount: y(5000), occurredAt: now.subtract(const Duration(days: 70))), owner);
      await env.ledger.record(NewTransaction(customerId: b.id, type: TxType.debit, amount: y(5000), occurredAt: now.subtract(const Duration(days: 70))), owner);
      await env.ledger.record(NewTransaction(customerId: b.id, type: TxType.credit, amount: y(100), occurredAt: now.subtract(const Duration(days: 5))), owner);
      final repo = OverdueRepository(env.db);
      final list = await repo.list(overdueDays: 30);
      expect(list.length, 1);
      expect(list.first.customer.name, 'أحمد');
      expect(list.first.bucket, AgingBucket.d60);
      expect(list.first.daysOverdue, 70);
      await repo.setPromise(a.id, DateTime.utc(2030, 1, 1));
      final list2 = await repo.list(overdueDays: 30);
      expect(list2.first.promiseDate, DateTime.utc(2030, 1, 1));
      expect(list2.first.promiseBroken, isFalse);
    });
  });

  group('ReportsRepository', () {
    test('summary, daily, top debtors, workers; reversed excluded', () async {
      final a = await customers.add(name: 'أحمد', byUserId: owner.userId);
      final b = await customers.add(name: 'بدر', byUserId: owner.userId);
      final now = DateTime.now().toUtc();
      await env.ledger.record(NewTransaction(customerId: a.id, type: TxType.debit, amount: y(3000), occurredAt: now), owner);
      await env.ledger.record(NewTransaction(customerId: a.id, type: TxType.credit, amount: y(1000), occurredAt: now), worker);
      await env.ledger.record(NewTransaction(customerId: b.id, type: TxType.debit, amount: y(9000), occurredAt: now), worker);
      final wrong = await env.ledger.record(NewTransaction(customerId: b.id, type: TxType.debit, amount: y(777), occurredAt: now), worker);
      await env.ledger.reverse(wrong.id, owner, reason: 'x');

      final repo = ReportsRepository(env.db);
      final (from, to) = ReportsRepository.range(ReportPeriod.today);
      final s = await repo.summary(Currency.yer, from, to);
      expect(s.took, y(12000));
      expect(s.paid, y(1000));
      expect(s.netChange, y(11000));
      expect(s.txCount, 3);
      expect(s.customersServed, 2);

      final days = await repo.daily(Currency.yer, from, to);
      expect(days.length, 1);
      expect(days.first.took, y(12000));

      final top = await repo.topDebtors(Currency.yer);
      expect(top.first.name, 'بدر');
      expect(top.first.balance, y(9000));

      final w = await repo.workers(Currency.yer, from, to);
      final wk = w.firstWhere((x) => x.userId == worker.userId);
      expect(wk.txCount, 3); // includes the reversed original (counted as recorded)
      expect(wk.reversals, 1);
      expect(wk.paid, y(1000));
    });

    test('week range starts Saturday', () {
      final (from, to) = ReportsRepository.range(ReportPeriod.week, now: DateTime(2026, 9, 9)); // Wednesday
      expect(from, DateTime(2026, 9, 5));
      expect(to, DateTime(2026, 9, 12));
    });
  });

  group('Activation', () {
    test('generate/verify bound to device, lifetime, expiry, normalisation', () {
      const dev = 'device-123';
      final code = Activation.generate(plan: 'Y1', expires: DateTime.utc(2027, 9, 9), deviceId: dev);
      expect(code, startsWith('SJL-Y1--'));
      final info = Activation.verify(code, dev)!;
      expect(info.plan, 'Y1');
      expect(info.expires, DateTime.utc(2027, 9, 9));
      expect(info.isValidAt(DateTime.utc(2026, 9, 9)), isTrue);
      expect(info.isValidAt(DateTime.utc(2028, 1, 1)), isFalse);
      // other device → invalid
      expect(Activation.verify(code, 'other'), isNull);
      // lowercase / no dashes / arabic digits accepted
      expect(Activation.verify(code.toLowerCase().replaceAll('-', ''), dev), isNotNull);
      // tampered
      expect(Activation.verify('${code.substring(0, code.length - 1)}A', dev), isNull);
      final life = Activation.generate(plan: 'LIFE', expires: null, deviceId: dev);
      expect(Activation.verify(life, dev)!.isLifetime, isTrue);
      expect(TrialPolicy.daysLeft(DateTime.utc(2026, 9, 1), DateTime.utc(2026, 9, 9)), 22);
    });
  });

  group('ReminderService template', () {
    test('render fills placeholders', () {
      final t = ReminderService.render('{shop}|{name}|{amount}|{words}', shopName: 'بقالة', customerName: 'أحمد', balance: y(2500));
      expect(t, 'بقالة|أحمد|2,500 ريال|ألفان وخمسمائة ريال يمني');
    });
  });

  group('BackupService', () {
    test('export → parse → restore is idempotent and never deletes', () async {
      final a = await customers.add(name: 'أحمد', byUserId: owner.userId);
      await env.ledger.record(NewTransaction(customerId: a.id, type: TxType.debit, amount: y(3000)), owner);
      final svc = BackupService(env.db, deviceId: deviceA);
      final bytes = await svc.exportBytes();
      final parsed = BackupService.parse(bytes);
      expect(parsed['format'], 'sijil-backup');
      expect((parsed['tables'] as Map)['transactions'], hasLength(1));

      // restore into same db → 0 new rows
      final counts = await svc.restore(bytes, safetyBackup: false);
      expect(counts['transactions'], 0);
      expect(counts['customers'], 0);
      expect((await env.ledger.balance(a.id, Currency.yer)).balance, y(3000));

      // tamper → rejected
      final tampered = Uint8List.fromList(bytes.toList());
      final idx = String.fromCharCodes(bytes).indexOf('"amount_minor":3000');
      expect(idx, greaterThan(0));
      tampered[idx + 15] = '4'.codeUnitAt(0); // 3000 → 4000 inside tables
      expect(() => BackupService.parse(tampered), throwsFormatException);
    });
  });

  group('DocLayout', () {
    test('presets encode/decode round trip', () {
      for (final p in DocPreset.values) {
        final l = DocLayout.preset(p).copyWith(footerText: 'x', numerals: 'arabic', showWorker: true);
        final back = DocLayout.decode(l.encode());
        expect(back.preset, p);
        expect(back.footerText, 'x');
        expect(back.arabicDigits, isTrue);
        expect(back.showWorker, isTrue);
        expect(back.margin, l.margin);
      }
    });
  });

  group('DocRenderer (real PDF bytes)', () {
    setUpAll(() {
      PdfHelpers.setFonts(
        tajawal: File('assets/fonts/Tajawal-Regular.ttf').readAsBytesSync(),
        tajawalBold: File('assets/fonts/Tajawal-Bold.ttf').readAsBytesSync(),
        amiri: File('assets/fonts/Amiri-Regular.ttf').readAsBytesSync(),
      );
    });

    test('all six kinds render non-empty PDFs in all three presets', () async {
      final now = DateTime.utc(2026, 9, 9, 10);
      const shop = DocShop(name: 'بقالة الأمل', address: 'صنعاء', phone: '777');
      const cust = DocCustomer(name: 'أحمد صالح', phone: '771');
      LedgerTx tx(String t, int a) => LedgerTx(
          id: 'i', shopId: 's', customerId: 'c', type: TxType.fromDb(t), amount: y(a), occurredAt: now, recordedAt: now, recordedBy: 'u',
          customerNameSnap: 'أحمد', userNameSnap: 'صالح', overLimit: false, inLockedPeriod: false, deviceId: 'd', localSeq: 7);
      final st = Statement(
          customerId: 'c', currency: Currency.yer, from: now.subtract(const Duration(days: 30)), to: now, opening: y(1000),
          lines: [StatementLine(tx('debit', 3000), y(4000)), StatementLine(tx('credit', 500), y(3500))],
          closing: y(3500), totalDebit: y(3000), totalCredit: y(500), totalAdjust: y(0));
      for (final p in DocPreset.values) {
        final l = DocLayout.preset(p);
        final outs = await Future.wait([
          DocRenderer.statement(StatementDoc(shop: shop, customer: cust, sections: [st], detailed: false, issuedAt: now), l),
          DocRenderer.statement(StatementDoc(shop: shop, customer: cust, sections: [st], detailed: true, issuedAt: now, watermarkTrial: true), l.copyWith(showWorker: true, showTime: true, numerals: 'arabic')),
          DocRenderer.receipt(ReceiptDoc(shop: shop, customer: cust, receiptNo: '7', payment: tx('credit', 500), balanceAfter: y(3500), issuedAt: now), l),
          DocRenderer.receipt(ReceiptDoc(shop: shop, customer: cust, receiptNo: '7', payment: tx('credit', 500), balanceAfter: y(0), issuedAt: now), l, thermal: true),
          DocRenderer.claim(ClaimDoc(shop: shop, customer: cust, balances: {Currency.yer: y(3500)}, lastPaymentAt: now, issuedAt: now), l),
          DocRenderer.overdueReport(OverdueReportDoc(shop: shop, currency: Currency.yer, rows: [OverdueRow(name: 'x', balance: y(10), lastPaymentAt: null, daysOverdue: 99)], issuedAt: now), l),
          DocRenderer.debtAck(DebtAckDoc(shop: shop, customer: cust, amount: y(3500), payBy: now, issuedAt: now), l),
        ]);
        for (final o in outs) {
          expect(o.length, greaterThan(1500), reason: 'preset $p produced tiny pdf');
          expect(String.fromCharCodes(o.take(5)), '%PDF-');
        }
      }
    });

    test('statement multi-currency sections stay separate (R4)', () async {
      final now = DateTime.utc(2026, 9, 9);
      const shop = DocShop(name: 'x');
      const cust = DocCustomer(name: 'y');
      Statement s(Currency c) => Statement(customerId: 'c', currency: c, from: now, to: now, opening: Money(0, c), lines: const [], closing: Money(100, c), totalDebit: Money(100, c), totalCredit: Money(0, c), totalAdjust: Money(0, c));
      final out = await DocRenderer.statement(StatementDoc(shop: shop, customer: cust, sections: [s(Currency.yer), s(Currency.sar)], detailed: false, issuedAt: now), DocLayout.preset(DocPreset.modern));
      expect(out.length, greaterThan(1500));
    });
  });
}
