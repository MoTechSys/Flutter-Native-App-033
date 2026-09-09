// اختبارات الأدوار ولوحة المدير: تسجيل كمدير/مستخدم، CRUD الكتب والتصنيفات،
// ترقية قاعدة البيانات v1→v2، وظهور لوحة الإدارة للمدير فقط
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitabi/data/db.dart';
import 'package:kitabi/data/repos/repos.dart';
import 'package:kitabi/models/models.dart';
import 'package:kitabi/state/session.dart';
import 'package:kitabi/state/store_state.dart';
import 'package:kitabi/ui/admin/admin_page.dart';
import 'package:kitabi/ui/admin/book_form_page.dart';
import 'package:kitabi/ui/profile/profile_page.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('الأدوار', () {
    setUp(() async {
      fakePrefs();
      await openTestDb();
    });
    tearDown(closeTestDb);

    test('التسجيل كمدير يُخزَّن role=1 ويُقرأ isAdmin=true؛ العادي false', () async {
      final repo = UserRepo();
      await repo.register(name: 'أحمد', email: 'admin@k.app', password: 'Pass1234', role: UserRole.admin);
      await repo.register(name: 'سارة', email: 'user@k.app', password: 'Pass1234');
      expect((await repo.byEmail('admin@k.app'))!.isAdmin, isTrue);
      expect((await repo.byEmail('user@k.app'))!.isAdmin, isFalse);

      final s = Session();
      expect(await s.signIn('admin@k.app', 'Pass1234'), isNull);
      expect(s.isAdmin, isTrue);
      await s.signOut();
      await s.signIn('user@k.app', 'Pass1234');
      expect(s.isAdmin, isFalse);
    });

    test('ترقية قاعدة v1 (بدون عمود role) إلى v2 تضيف العمود وتحافظ على البيانات', () async {
      await closeTestDb();
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      // قاعدة v1 يدوية بمستخدم واحد (ملف مؤقت لأن الذاكرة لا تبقى بين الاتصالات)
      final tmp = '${Directory.systemTemp.path}/kitabi_mig_${DateTime.now().microsecondsSinceEpoch}.db';
      final d1 = await openDatabase(tmp, version: 1, onCreate: (d, _) async {
        await d.execute('CREATE TABLE users(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, email TEXT NOT NULL UNIQUE, password TEXT NOT NULL, phone TEXT, city TEXT, created_at TEXT NOT NULL)');
        await d.insert('users', {'name': 'قديم', 'email': 'old@k.app', 'password': 'x', 'created_at': 'now'});
      });
      await d1.close();

      KitabiDb.instance.pathOverride = tmp;
      await KitabiDb.instance.open(); // يُشغّل onUpgrade 1→2
      final rows = await KitabiDb.instance.db.query('users');
      expect(rows.single['name'], 'قديم');
      expect(rows.single['role'], 0); // العمود الجديد بقيمته الافتراضية
      await KitabiDb.instance.close();
      KitabiDb.instance.pathOverride = null;
      await File(tmp).delete();
    });
  });

  group('CRUD الكتالوج (المدير)', () {
    late CatalogState catalog;
    setUp(() async {
      fakePrefs();
      await openTestDb();
      catalog = CatalogState();
      await catalog.load();
    });
    tearDown(closeTestDb);

    test('إضافة كتاب → يظهر في القائمة والبحث والتصنيف؛ تعديل؛ حذف يزيله من السلة والمفضلة', () async {
      final cat = catalog.categories.first;
      final before = catalog.books.length;
      final added = await catalog.addBook(Book(
        id: 0,
        categoryId: cat.id,
        title: 'كتاب اختباري جديد',
        author: 'مؤلف',
        description: 'وصف تجريبي للكتاب الجديد',
        price: 30,
        rating: 4.2,
        pages: 100,
        year: 2024,
        cover: 'generated',
        coverColor: cat.color,
        featured: true,
      ));
      expect(added.id, greaterThan(0));
      expect(catalog.books.length, before + 1);
      expect(catalog.search('اختباري').single.id, added.id);
      expect(catalog.byCategory(cat.id).any((b) => b.id == added.id), isTrue);
      expect(catalog.featured.any((b) => b.id == added.id), isTrue);

      await catalog.updateBook(added.copyWith(title: 'عنوان معدّل', price: 25, oldPrice: 40));
      final edited = catalog.book(added.id)!;
      expect(edited.title, 'عنوان معدّل');
      expect(edited.hasDiscount, isTrue);
      expect(edited.discountPercent, 38);

      // مستخدم يضيفه للسلة والمفضلة ثم يحذفه المدير → CASCADE
      await UserRepo().register(name: 'ز', email: 'z@k.app', password: 'Pass1234');
      final uid = (await UserRepo().byEmail('z@k.app'))!.id;
      await CartRepo().add(uid, added.id);
      await FavoriteRepo().toggle(uid, added.id);
      await catalog.deleteBook(added.id);
      expect(catalog.book(added.id), isNull);
      expect(catalog.books.length, before);
      expect(await CartRepo().lines(uid), isEmpty);
      expect(await FavoriteRepo().ids(uid), isEmpty);
    });

    test('التصنيفات: إضافة وتعديل؛ حذف مرفوض إن كان فيه كتب ومقبول إن كان فارغاً', () async {
      final c = await catalog.addCategory(name: 'شعر', slug: 'poetry', color: 0xFFA33D6E);
      expect(catalog.categories.any((x) => x.id == c.id), isTrue);

      await catalog.updateCategory(Category(id: c.id, name: 'شعر ونثر', slug: 'poetry', color: 0xFF1F6F8B));
      expect(catalog.category(c.id)!.name, 'شعر ونثر');

      // تصنيف "روايات" فيه 4 كتب → مرفوض
      final novels = catalog.categories.first;
      expect(await catalog.deleteCategory(novels.id), isFalse);
      expect(catalog.category(novels.id), isNotNull);

      // الفارغ → يُحذف
      expect(await catalog.deleteCategory(c.id), isTrue);
      expect(catalog.category(c.id), isNull);
    });

    test('bestSellers تُرتّب حسب الكمية المبيعة', () async {
      await UserRepo().register(name: 'ب', email: 'b@k.app', password: 'Pass1234');
      final uid = (await UserRepo().byEmail('b@k.app'))!.id;
      final books = catalog.books;
      await OrderRepo().placeOrder(uid, [CartLine(book: books[0], qty: 1), CartLine(book: books[1], qty: 5)]);
      final best = await CatalogRepo().bestSellers(limit: 2);
      expect(best.first.$1.id, books[1].id);
      expect(best.first.$2, 5);
      expect(await OrderRepo().countAll(), 1);
      expect(await OrderRepo().revenue(), closeTo(books[0].price + books[1].price * 5, 0.01));
    });
  });

  group('واجهة المدير', () {
    setUp(() async {
      fakePrefs();
      await openTestDb();
    });
    tearDown(closeTestDb);

    Future<Widget> hostAs(UserRole role, Widget page) async {
      final session = Session();
      await session.signUp(name: 'م', email: '${role.name}@k.app', password: 'Secret123', role: role);
      final catalog = CatalogState();
      await catalog.load();
      final cart = CartState();
      await cart.bind(session.uid);
      final fav = FavoritesState();
      await fav.bind(session.uid);
      return MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: session),
          ChangeNotifierProvider.value(value: catalog),
          ChangeNotifierProvider.value(value: cart),
          ChangeNotifierProvider.value(value: fav),
        ],
        child: host(page),
      );
    }

    testWidgets('لوحة الإدارة تظهر في "حسابي" للمدير فقط', (t) async {
      await phoneSize(t);
      late Widget w;
      await t.runAsync(() async => w = await hostAs(UserRole.admin, const ProfilePage()));
      await t.pumpWidget(w);
      await t.pumpAndSettle();
      expect(find.text('لوحة إدارة المتجر'), findsOneWidget);
      expect(find.text('مدير'), findsOneWidget);

      await t.runAsync(() async => w = await hostAs(UserRole.customer, const ProfilePage()));
      await t.pumpWidget(w);
      await t.pumpAndSettle();
      expect(find.text('لوحة إدارة المتجر'), findsNothing);
      expect(find.text('مدير'), findsNothing);
    });

    testWidgets('نموذج إضافة كتاب: يرفض الفارغ ثم يحفظ فعلاً في SQLite', (t) async {
      await phoneSize(t);
      late Widget w;
      await t.runAsync(() async => w = await hostAs(UserRole.admin, const BookFormPage()));
      await t.pumpWidget(w);
      await t.pumpAndSettle();

      await t.scrollUntilVisible(find.text('إضافة الكتاب'), 200, scrollable: find.byType(Scrollable).first);
      await t.tap(find.text('إضافة الكتاب'));
      await t.pumpAndSettle();
      expect(find.text('أدخل عنوان الكتاب'), findsOneWidget); // تحقق
      await t.scrollUntilVisible(find.widgetWithText(TextFormField, 'عنوان الكتاب'), -200, scrollable: find.byType(Scrollable).first);

      await t.enterText(find.widgetWithText(TextFormField, 'عنوان الكتاب'), 'الأيام');
      await t.enterText(find.widgetWithText(TextFormField, 'المؤلف'), 'طه حسين');
      await t.scrollUntilVisible(find.widgetWithText(TextFormField, 'السعر (ر.س)'), 100, scrollable: find.byType(Scrollable).first);
      await t.enterText(find.widgetWithText(TextFormField, 'السعر (ر.س)'), '35');
      await t.enterText(find.widgetWithText(TextFormField, 'عدد الصفحات'), '320');
      await t.enterText(find.widgetWithText(TextFormField, 'سنة النشر'), '1929');
      await t.scrollUntilVisible(find.widgetWithText(TextFormField, 'الوصف'), 100, scrollable: find.byType(Scrollable).first);
      await t.enterText(find.widgetWithText(TextFormField, 'الوصف'), 'سيرة ذاتية لعميد الأدب العربي في ثلاثة أجزاء.');
      await t.scrollUntilVisible(find.byKey(const Key('book_category')), -100, scrollable: find.byType(Scrollable).first);
      await t.pumpAndSettle();
      // نفتح القائمة عبر عنصر DropdownButton الداخلي (مركز الحقل)
      await t.tap(find.descendant(of: find.byKey(const Key('book_category')), matching: find.byType(DropdownButton<int>)));
      await t.pumpAndSettle();
      expect(find.text('روايات'), findsWidgets, reason: 'قائمة التصنيفات مفتوحة');
      await t.tap(find.text('روايات').last);
      await t.pumpAndSettle();

      await t.scrollUntilVisible(find.text('إضافة الكتاب'), 200, scrollable: find.byType(Scrollable).first);
      await t.runAsync(() async {
        await t.tap(find.text('إضافة الكتاب'));
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      await t.pumpAndSettle();

      final books = await t.runAsync(() => CatalogRepo().books());
      expect(books!.any((b) => b.title == 'الأيام' && b.author == 'طه حسين'), isTrue);
      expect(find.byType(BookFormPage), findsNothing); // أُغلق النموذج
    });

    testWidgets('لوحة الإدارة تعرض التبويبات الثلاثة والكتب', (t) async {
      await phoneSize(t);
      late Widget w;
      await t.runAsync(() async => w = await hostAs(UserRole.admin, const AdminPage()));
      await t.pumpWidget(w);
      await t.pumpAndSettle();
      expect(find.text('الكتب'), findsWidgets);
      expect(find.text('التصنيفات'), findsWidgets);
      expect(find.text('الإحصاءات'), findsWidgets);
      expect(find.text('إضافة كتاب'), findsOneWidget);
      expect(find.text('موسم الهجرة إلى الشمال'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });
}
