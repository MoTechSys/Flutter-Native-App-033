// اختبارات طبقة البيانات: البذر بكتب حقيقية + CRUD كامل على SQLite (في الذاكرة)
import 'package:flutter_test/flutter_test.dart';
import 'package:kitabi/data/repos/repos.dart';
import 'package:kitabi/models/models.dart';

import 'helpers.dart';

void main() {
  setUp(openTestDb);
  tearDown(closeTestDb);

  group('Seed (بيانات حقيقية عند أول تشغيل)', () {
    test('6 تصنيفات و 24 كتاباً حقيقياً بأغلفة موجودة', () async {
      final repo = CatalogRepo();
      final cats = await repo.categories();
      final books = await repo.books();
      expect(cats.length, 6);
      expect(books.length, 24);
      expect(books.map((b) => b.title), containsAll(['موسم الهجرة إلى الشمال', 'العادات الذرية', 'الأمير الصغير']));
      expect(books.where((b) => b.author == 'الطيب صالح').length, 1);
      for (final b in books) {
        expect(b.cover, 'assets/covers/book_${b.id}.png');
        expect(b.price, greaterThan(0));
        expect(b.rating, inInclusiveRange(1, 5));
      }
      // كل تصنيف فيه 4 كتب
      for (final c in cats) {
        expect(await repo.countByCategory(c.id), 4);
      }
    });
  });

  group('UserRepo (Create/Read/Update/Delete)', () {
    final repo = UserRepo();

    test('تسجيل ثم مصادقة ثم رفض التكرار', () async {
      expect(await repo.register(name: 'علي', email: 'ali@x.com', password: 'Pass1234'), isNull);
      final dup = await repo.register(name: 'علي', email: 'ALI@x.com', password: 'Pass1234');
      expect(dup, isNotNull); // البريد مكرر (غير حساس لحالة الأحرف)
      expect(await repo.authenticate('ali@x.com', 'Pass1234'), isNotNull);
      expect(await repo.authenticate('ali@x.com', 'wrong'), isNull);
    });

    test('تحديث الملف وتغيير كلمة المرور واستعادتها وحذف الحساب', () async {
      await repo.register(name: 'سارة', email: 's@x.com', password: 'Pass1234', city: 'عدن');
      final u = (await repo.byEmail('s@x.com'))!;
      await repo.updateProfile(u.id, name: 'سارة أحمد', phone: '777', city: 'تعز');
      final u2 = (await repo.byId(u.id))!;
      expect(u2.name, 'سارة أحمد');
      expect(u2.city, 'تعز');

      expect(await repo.changePassword(u.id, 'bad', 'New12345'), isFalse);
      expect(await repo.changePassword(u.id, 'Pass1234', 'New12345'), isTrue);
      expect(await repo.authenticate('s@x.com', 'New12345'), isNotNull);

      await repo.resetPassword('s@x.com', 'Reset999');
      expect(await repo.authenticate('s@x.com', 'Reset999'), isNotNull);

      await repo.deleteAccount(u.id);
      expect(await repo.byId(u.id), isNull);
    });
  });

  group('Cart / Favorites / Orders / Reviews', () {
    late int uid;
    late List<Book> books;

    setUp(() async {
      await UserRepo().register(name: 'م', email: 'm@x.com', password: 'Pass1234');
      uid = (await UserRepo().byEmail('m@x.com'))!.id;
      books = await CatalogRepo().books();
    });

    test('السلة: إضافة (upsert) وتعديل الكمية وحذف وتفريغ', () async {
      final cart = CartRepo();
      await cart.add(uid, books[0].id);
      await cart.add(uid, books[0].id, qty: 2); // يزيد الكمية على نفس الصف
      await cart.add(uid, books[1].id);
      var lines = await cart.lines(uid);
      expect(lines.length, 2);
      expect(lines.firstWhere((l) => l.book.id == books[0].id).qty, 3);

      await cart.setQty(uid, books[0].id, 1);
      await cart.setQty(uid, books[1].id, 0); // صفر = حذف
      lines = await cart.lines(uid);
      expect(lines.length, 1);
      expect(lines.single.qty, 1);

      await cart.remove(uid, books[0].id);
      expect(await cart.lines(uid), isEmpty);
    });

    test('المفضلة: تبديل يُعيد true عند الإضافة وfalse عند الإزالة', () async {
      final fav = FavoriteRepo();
      expect(await fav.toggle(uid, books[2].id), isTrue);
      expect(await fav.toggle(uid, books[3].id), isTrue);
      expect((await fav.ids(uid)).length, 2);
      expect(await fav.toggle(uid, books[2].id), isFalse);
      expect((await fav.books(uid)).single.id, books[3].id);
      await fav.clear(uid);
      expect(await fav.ids(uid), isEmpty);
    });

    test('الطلبات: إنشاء داخل Transaction ثم تقدم الحالة ثم منع الإلغاء بعد التسليم', () async {
      final orders = OrderRepo();
      final lines = [CartLine(book: books[0], qty: 2), CartLine(book: books[5], qty: 1)];
      final o = await orders.placeOrder(uid, lines, discount: 10, coupon: 'KITABI10');
      expect(o.lines.length, 2);
      expect(o.subtotal, closeTo(books[0].price * 2 + books[5].price, 0.001));
      expect(o.total, closeTo(o.subtotal - 10, 0.001));
      expect(o.status, OrderStatus.placed);

      await orders.advanceStatus(o.id, OrderStatus.processing);
      expect((await orders.byId(o.id))!.status, OrderStatus.processing);
      expect((await orders.forUser(uid)).length, 1);

      await orders.advanceStatus(o.id, OrderStatus.delivered);
      expect(await orders.cancel(o.id), isFalse); // مُسلَّم → لا يُلغى
      expect(await orders.byId(o.id), isNotNull);

      final o2 = await orders.placeOrder(uid, lines);
      expect(await orders.cancel(o2.id), isTrue);
      expect(await orders.byId(o2.id), isNull);
    });

    test('التقييمات: upsert يستبدل تقييم نفس المستخدم ثم حذف', () async {
      final rv = ReviewRepo();
      await rv.upsert(books[0].id, uid, 4, 'جيد');
      await rv.upsert(books[0].id, uid, 5, 'ممتاز');
      final list = await rv.forBook(books[0].id);
      expect(list.length, 1);
      expect(list.single.stars, 5);
      expect(list.single.text, 'ممتاز');
      expect(list.single.userName, 'م');
      expect(await rv.countForBook(books[0].id), 1);
      final mine = await rv.mine(books[0].id, uid);
      expect(mine, isNotNull);
      await rv.delete(mine!.id);
      expect(await rv.forBook(books[0].id), isEmpty);
    });

    test('حذف المستخدم يحذف سلته ومفضلته وطلباته (FK CASCADE)', () async {
      await CartRepo().add(uid, books[0].id);
      await FavoriteRepo().toggle(uid, books[1].id);
      await OrderRepo().placeOrder(uid, [CartLine(book: books[0], qty: 1)]);
      await UserRepo().deleteAccount(uid);
      expect(await CartRepo().lines(uid), isEmpty);
      expect(await FavoriteRepo().ids(uid), isEmpty);
      expect(await OrderRepo().forUser(uid), isEmpty);
    });
  });
}
