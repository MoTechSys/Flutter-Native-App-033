// اختبارات الترخيص البعيد (4 حالات) + محرّك OTP
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kitabi/security/access_control.dart';
import 'package:kitabi/security/otp_engine.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AccessControl', () {
    setUp(() => fakePrefs());

    test('active=true → Granted فوراً', () async {
      AccessControl.transport = fakeServer(active: true);
      final d = await AccessControl.resolve();
      expect(d, isA<Granted>());
      expect(d.allowed, isTrue);
    });

    test('active=false → Locked ثم redeem بالكود الصحيح يفتح ويبقى مفتوحاً', () async {
      AccessControl.transport = fakeServer(active: false, code: 'KTB-2025');
      expect(await AccessControl.resolve(), isA<Locked>());
      expect(await AccessControl.redeem('wrong'), isFalse);
      expect(await AccessControl.redeem(' ktb-2025 '), isTrue); // غير حساس للحالة والمسافات
      // التشغيل التالي (نفس الكود على الخادم) يفتح مباشرة
      expect(await AccessControl.resolve(), isA<Granted>());
      // تغيّر الكود على الخادم → يُقفل مجدداً
      AccessControl.transport = fakeServer(active: false, code: 'KTB-NEW1');
      expect(await AccessControl.resolve(), isA<Locked>());
    });

    test('404 (الملف محذوف) → Terminated ولا يقبل أي كود', () async {
      AccessControl.transport = fakeServer(gone: true);
      final d = await AccessControl.resolve();
      expect(d, isA<Terminated>());
      expect(d.allowed, isFalse);
      expect(await AccessControl.redeem('KTB-2025'), isFalse);
    });

    test('offline → Offline بآخر حالة محفوظة', () async {
      AccessControl.transport = fakeServer(active: true);
      await AccessControl.resolve(); // يحفظ Granted
      AccessControl.transport = fakeServer(offline: true);
      final d = await AccessControl.resolve();
      expect(d, isA<Offline>());
      expect((d as Offline).last, isA<Granted>());
      expect(d.allowed, isTrue);

      // بلا أي حالة سابقة + offline → آخر حالة افتراضية (Granted) حتى لا يُحرم المستخدم بلا إنترنت
      fakePrefs();
      final d2 = await AccessControl.resolve();
      expect(d2, isA<Offline>());
    });
  });

  group('OtpEngine', () {
    test('يولّد 5 خانات من أبجدية بلا 0/O/1/I ويعرض XX-XXX', () {
      final e = OtpEngine(Random(7));
      final c = e.issue();
      expect(c.length, 5);
      expect(c, isNot(matches(RegExp('[0O1I]'))));
      expect(e.display, matches(RegExp(r'^[A-Z2-9]{2}-[A-Z2-9]{3}$')));
      expect(e.remaining.inSeconds, inInclusiveRange(118, 120));
      expect(e.canResend, isFalse);
    });

    test('التحقق: خطأ مرتين ثم صحيح؛ الصحيح يقبل الشرطة والأحرف الصغيرة', () {
      final e = OtpEngine(Random(1));
      final c = e.issue();
      expect(e.verify('AAAAA'), OtpResult.wrong);
      expect(e.attemptsLeft, 2);
      expect(e.verify('BBBBB'), OtpResult.wrong);
      expect(e.verify('${c.substring(0, 2).toLowerCase()}-${c.substring(2)}'), OtpResult.ok);
      expect(e.hasCode, isFalse);
      expect(e.verify(c), OtpResult.noCode);
    });

    test('3 محاولات خاطئة → lockedOut ويُلغى الرمز', () {
      final e = OtpEngine(Random(3));
      e.issue();
      expect(e.verify('X'), OtpResult.wrong);
      expect(e.verify('X'), OtpResult.wrong);
      expect(e.verify('X'), OtpResult.lockedOut);
      expect(e.hasCode, isFalse);
      expect(e.verify('X'), OtpResult.noCode);
    });

    test('reset يمسح كل شيء ويسمح بإعادة الإرسال', () {
      final e = OtpEngine(Random(9));
      e.issue();
      e.reset();
      expect(e.hasCode, isFalse);
      expect(e.canResend, isTrue);
      expect(e.remaining, Duration.zero);
    });
  });
}
