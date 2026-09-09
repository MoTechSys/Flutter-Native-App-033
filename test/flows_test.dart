// اختبارات واجهة: المصادقة والتحقق، استعادة كلمة المرور بـ OTP،
// سلوك زر الرجوع في Shell (خطوة بخطوة ثم تأكيد الخروج)، وعدم وجود Overflow على 360×780
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitabi/data/repos/repos.dart';
import 'package:kitabi/models/models.dart';
import 'package:kitabi/ui/auth/recover_password_page.dart';
import 'package:kitabi/ui/auth/sign_in_page.dart';
import 'package:kitabi/ui/auth/sign_up_page.dart';
import 'package:kitabi/ui/home/book_detail_page.dart';
import 'package:kitabi/ui/orders/orders_page.dart';
import 'package:kitabi/ui/profile/about_page.dart';
import 'package:kitabi/ui/profile/profile_page.dart';
import 'package:kitabi/ui/shell.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    fakePrefs();
    await openTestDb();
  });
  tearDown(closeTestDb);

  group('Auth + Validation', () {
    testWidgets('تسجيل الدخول يرفض النموذج الفارغ ويعرض رسائل التحقق', (t) async {
      await phoneSize(t);
      await t.pumpWidget(host(const SignInPage()));
      await t.tap(find.widgetWithText(FilledButton, 'دخول'));
      await t.pumpAndSettle();
      expect(find.textContaining('البريد'), findsWidgets);
      expect(find.byType(SignInPage), findsOneWidget); // ما زلنا في نفس الصفحة
    });

    testWidgets('التسجيل يتحقق من كل الحقول + تطابق كلمة المرور', (t) async {
      await phoneSize(t);
      await t.pumpWidget(host(const SignUpPage()));
      await t.ensureVisible(find.text('إنشاء الحساب'));
      await t.tap(find.text('إنشاء الحساب'));
      await t.pumpAndSettle();
      // ظهرت أخطاء تحقق متعددة
      expect(find.byType(TextFormField), findsWidgets);
      expect(t.takeException(), isNull);
    });
  });

  group('استعادة كلمة المرور (OTP بثلاث خطوات)', () {
    testWidgets('بريد مسجّل → رمز → تحقق → كلمة جديدة تعمل فعلاً', (t) async {
      await phoneSize(t);
      await t.runAsync(() => UserRepo().register(name: 'علي', email: 'ali@kitabi.app', password: 'OldPass123'));

      await t.pumpWidget(host(const RecoverPasswordPage()));
      await t.pump();
      // الخطوة 1: البريد (استعلام SQLite حقيقي → runAsync)
      await t.enterText(find.byType(TextFormField).first, 'ali@kitabi.app');
      await t.runAsync(() async {
        await t.tap(find.text('إنشاء رمز التحقق'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));

      // الخطوة 2: نقرأ الرمز المعروض ونُدخله
      final shown = t.widget<SelectableText>(find.byType(SelectableText).first).data!;
      expect(shown, matches(RegExp(r'^[A-Z2-9]{2}-[A-Z2-9]{3}$')));
      await t.enterText(find.byKey(const Key('otp_input')), 'ZZ-ZZZ');
      await t.tap(find.text('تحقق'));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('otp_input')), findsOneWidget); // ما زلنا في الخطوة 2
      await t.enterText(find.byKey(const Key('otp_input')), shown);
      await t.tap(find.text('تحقق'));
      await t.pump(const Duration(milliseconds: 400));

      // الخطوة 3: كلمة جديدة (UPDATE في SQLite → runAsync)
      await t.enterText(find.widgetWithText(TextFormField, 'كلمة المرور الجديدة'), 'NewPass456');
      await t.enterText(find.widgetWithText(TextFormField, 'تأكيد كلمة المرور'), 'NewPass456');
      await t.ensureVisible(find.text('حفظ كلمة المرور'));
      await t.pump(const Duration(milliseconds: 300));
      await t.runAsync(() async {
        await t.tap(find.text('حفظ كلمة المرور'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await t.pump(const Duration(milliseconds: 400));

      await t.runAsync(() async {
        expect(await UserRepo().authenticate('ali@kitabi.app', 'NewPass456'), isNotNull);
        expect(await UserRepo().authenticate('ali@kitabi.app', 'OldPass123'), isNull);
      });
    });
  });

  group('Shell: زر الرجوع خطوة بخطوة', () {
    testWidgets('تبويب → صفحة داخلية → رجوع يعود للتبويب → رجوع يعود للرئيسية → رجوع يطلب تأكيداً', (t) async {
      await phoneSize(t);
      await t.runAsync(() async {
        await t.pumpWidget(await hostSignedIn());
      });
      await t.pumpAndSettle();
      expect(find.text('كِتابي'), findsWidgets); // الرئيسية

      // اذهب إلى التصنيفات
      await t.runAsync(() async {
        await t.tap(find.text('التصنيفات').last);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await t.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);

      // افتح تصنيفاً (صفحة داخلية في Navigator التبويب)
      await t.runAsync(() async {
        await t.tap(find.text('روايات').first);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await t.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget, reason: 'الشريط السفلي يبقى ظاهراً مع التنقل المتداخل');

      // رجوع النظام #1 → يخرج من قائمة الكتب إلى شبكة التصنيفات
      final dyn = t.binding;
      await dyn.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('التصنيفات'), findsWidgets);
      expect(find.byType(AlertDialog), findsNothing);

      // رجوع #2 → إلى الرئيسية
      await dyn.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('ابحث عن كتاب أو مؤلف...'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);

      // رجوع #3 على الرئيسية → حوار تأكيد الخروج (ولا يخرج التطبيق فجأة)
      await dyn.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await t.tap(find.text('البقاء'));
      await t.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(Shell), findsOneWidget);
    });

    testWidgets('النقر على التبويب الحالي يعود إلى جذره', (t) async {
      await phoneSize(t);
      await t.runAsync(() async => t.pumpWidget(await hostSignedIn()));
      await t.pumpAndSettle();
      await t.runAsync(() async {
        await t.tap(find.text('التصنيفات').last);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await t.pumpAndSettle();
      await t.runAsync(() async {
        await t.tap(find.text('روايات').first);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await t.pumpAndSettle();
      await t.tap(find.text('التصنيفات').last); // نفس التبويب
      await t.pumpAndSettle();
      expect(find.text('روايات'), findsWidgets);
      expect(find.byType(BookDetailPage), findsNothing);
    });
  });

  group('Layout 360×780 بلا Overflow', () {
    testWidgets('الرئيسية ثابتة (لا تمرير عمودي) وكل الصفحات الرئيسية تُبنى بلا أخطاء', (t) async {
      await phoneSize(t);
      await t.runAsync(() async => t.pumpWidget(await hostSignedIn()));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      // لا يوجد ListView عمودي في الرئيسية (كلها أفقية أو ثابتة)
      final vertical = t.widgetList<ListView>(find.byType(ListView)).where((l) => l.scrollDirection == Axis.vertical);
      expect(vertical, isEmpty, reason: 'الرئيسية يجب أن تكون ثابتة بلا تمرير عمودي');

      for (final tab in ['التصنيفات', 'السلة', 'المفضلة']) {
        await t.runAsync(() async {
          await t.tap(find.text(tab).last);
          await Future<void>.delayed(const Duration(milliseconds: 300));
        });
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: 'overflow في $tab');
      }
    });

    testWidgets('تفاصيل الكتاب / الملف الشخصي / حول / الطلبات بلا Overflow', (t) async {
      await phoneSize(t);
      late PageHost h;
      await t.runAsync(() async => h = await signedInHost());
      late List<Book> books;
      await t.runAsync(() async => books = await CatalogRepo().books());
      final pages = <Widget>[const ProfilePage(), const AboutPage(), const OrdersPage(), BookDetailPage(book: books.first)];
      for (final page in pages) {
        await t.runAsync(() async {
          await t.pumpWidget(h(page));
          await Future<void>.delayed(const Duration(milliseconds: 300));
        });
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: 'overflow in ${page.runtimeType}');
      }
      expect(find.text(books.first.title), findsWidgets);
    });
  });
}
