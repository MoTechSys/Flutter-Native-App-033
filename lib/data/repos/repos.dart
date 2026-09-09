// ============================================================
// كِتابي - مستودعات البيانات (CRUD لكل كيان)
// ============================================================

import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';

import '../../models/models.dart';
import '../db.dart';

Database get _db => KitabiDb.instance.db;
String _now() => DateTime.now().toIso8601String();

// ------------------------------------------------------------ Users
class UserRepo {
  static String _hash(String p) => sha256.convert(utf8.encode('kitabi::$p')).toString();

  Future<String?> register({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? city,
    UserRole role = UserRole.customer,
  }) async {
    final e = email.trim().toLowerCase();
    final dup = await _db.query('users', where: 'email = ?', whereArgs: [e]);
    if (dup.isNotEmpty) return 'هذا البريد مسجّل مسبقاً';
    await _db.insert('users', {
      'name': name.trim(),
      'email': e,
      'password': _hash(password),
      'phone': phone,
      'city': city,
      'role': role == UserRole.admin ? 1 : 0,
      'created_at': _now(),
    });
    return null;
  }

  Future<int> countAll() async => Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM users')) ?? 0;

  Future<AppUser?> authenticate(String email, String password) async {
    final rows = await _db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email.trim().toLowerCase(), _hash(password)],
    );
    return rows.isEmpty ? null : AppUser.fromRow(rows.first);
  }

  Future<AppUser?> byEmail(String email) async {
    final rows = await _db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
    );
    return rows.isEmpty ? null : AppUser.fromRow(rows.first);
  }

  Future<AppUser?> byId(int id) async {
    final rows = await _db.query('users', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : AppUser.fromRow(rows.first);
  }

  Future<void> updateProfile(int id, {required String name, String? phone, String? city}) =>
      _db.update(
        'users',
        {'name': name.trim(), 'phone': phone, 'city': city},
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<bool> changePassword(int id, String current, String next) async {
    final n = await _db.update(
      'users',
      {'password': _hash(next)},
      where: 'id = ? AND password = ?',
      whereArgs: [id, _hash(current)],
    );
    return n == 1;
  }

  Future<void> resetPassword(String email, String next) => _db.update(
    'users',
    {'password': _hash(next)},
    where: 'email = ?',
    whereArgs: [email.trim().toLowerCase()],
  );

  Future<void> deleteAccount(int id) =>
      _db.delete('users', where: 'id = ?', whereArgs: [id]);
}

// ------------------------------------------------------------ Catalog
class CatalogRepo {
  Future<List<Category>> categories() async =>
      (await _db.query('categories', orderBy: 'id')).map(Category.fromRow).toList();

  Future<List<Book>> books() async =>
      (await _db.query('books', orderBy: 'id')).map(Book.fromRow).toList();

  Future<Book?> book(int id) async {
    final r = await _db.query('books', where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? null : Book.fromRow(r.first);
  }

  Future<int> countByCategory(int categoryId) async =>
      Sqflite.firstIntValue(await _db.rawQuery(
        'SELECT COUNT(*) FROM books WHERE category_id = ?',
        [categoryId],
      )) ??
      0;

  // ---------------- كتابة (لوحة المدير) ----------------

  /// إضافة كتاب جديد؛ يُعيد المعرّف المُولَّد
  Future<int> insertBook(Book b) async {
    final row = b.toRow()..remove('id');
    return _db.insert('books', row);
  }

  Future<void> updateBook(Book b) =>
      _db.update('books', b.toRow()..remove('id'), where: 'id = ?', whereArgs: [b.id]);

  /// حذف كتاب — يحذف تلقائياً من السلال والمفضلات والمراجعات (CASCADE)
  Future<void> deleteBook(int id) => _db.delete('books', where: 'id = ?', whereArgs: [id]);

  Future<int> insertCategory({required String name, required String slug, required int color}) =>
      _db.insert('categories', {'name': name, 'slug': slug, 'color': color});

  Future<void> updateCategory(Category c) =>
      _db.update('categories', c.toRow()..remove('id'), where: 'id = ?', whereArgs: [c.id]);

  /// حذف تصنيف — مرفوض إن كان فيه كتب (يُعيد false)
  Future<bool> deleteCategory(int id) async {
    if (await countByCategory(id) > 0) return false;
    await _db.delete('categories', where: 'id = ?', whereArgs: [id]);
    return true;
  }

  /// أكثر الكتب مبيعاً (من عناصر الطلبات)
  Future<List<(Book, int)>> bestSellers({int limit = 5}) async {
    final rows = await _db.rawQuery('''
      SELECT b.*, SUM(oi.qty) AS sold FROM order_items oi
      JOIN books b ON b.id = oi.book_id
      GROUP BY oi.book_id ORDER BY sold DESC LIMIT ?
    ''', [limit]);
    return rows.map((r) => (Book.fromRow(r), (r['sold'] as num).toInt())).toList();
  }
}

// ------------------------------------------------------------ Cart
class CartRepo {
  Future<List<CartLine>> lines(int userId) async {
    final rows = await _db.rawQuery('''
      SELECT b.*, c.qty FROM cart_items c
      JOIN books b ON b.id = c.book_id
      WHERE c.user_id = ? ORDER BY b.title''', [userId]);
    return rows.map((r) => CartLine(book: Book.fromRow(r), qty: r['qty'] as int)).toList();
  }

  Future<void> add(int userId, int bookId, {int qty = 1}) async {
    await _db.rawInsert('''
      INSERT INTO cart_items(user_id, book_id, qty) VALUES(?, ?, ?)
      ON CONFLICT(user_id, book_id) DO UPDATE SET qty = qty + excluded.qty''',
      [userId, bookId, qty]);
  }

  Future<void> setQty(int userId, int bookId, int qty) async {
    if (qty <= 0) {
      await remove(userId, bookId);
    } else {
      await _db.update(
        'cart_items',
        {'qty': qty},
        where: 'user_id = ? AND book_id = ?',
        whereArgs: [userId, bookId],
      );
    }
  }

  Future<void> remove(int userId, int bookId) => _db.delete(
    'cart_items',
    where: 'user_id = ? AND book_id = ?',
    whereArgs: [userId, bookId],
  );

  Future<void> clear(int userId) =>
      _db.delete('cart_items', where: 'user_id = ?', whereArgs: [userId]);
}

// ------------------------------------------------------------ Favorites
class FavoriteRepo {
  Future<Set<int>> ids(int userId) async =>
      (await _db.query('favorites', columns: ['book_id'], where: 'user_id = ?', whereArgs: [userId]))
          .map((r) => r['book_id'] as int)
          .toSet();

  Future<List<Book>> books(int userId) async {
    final rows = await _db.rawQuery('''
      SELECT b.* FROM favorites f JOIN books b ON b.id = f.book_id
      WHERE f.user_id = ? ORDER BY f.added_at DESC''', [userId]);
    return rows.map(Book.fromRow).toList();
  }

  Future<bool> toggle(int userId, int bookId) async {
    final n = await _db.delete(
      'favorites',
      where: 'user_id = ? AND book_id = ?',
      whereArgs: [userId, bookId],
    );
    if (n > 0) return false;
    await _db.insert('favorites', {
      'user_id': userId,
      'book_id': bookId,
      'added_at': _now(),
    });
    return true;
  }

  Future<void> clear(int userId) =>
      _db.delete('favorites', where: 'user_id = ?', whereArgs: [userId]);
}

// ------------------------------------------------------------ Orders
class OrderRepo {
  /// يحوّل السلة إلى طلب ويُفرغها (معاملة واحدة)
  Future<Order> placeOrder(
    int userId,
    List<CartLine> lines, {
    double discount = 0,
    String? coupon,
  }) async {
    final subtotal = lines.fold<double>(0, (a, l) => a + l.total);
    final total = (subtotal - discount).clamp(0, double.infinity).toDouble();
    late int id;
    await _db.transaction((tx) async {
      id = await tx.insert('orders', {
        'user_id': userId,
        'created_at': _now(),
        'subtotal': subtotal,
        'discount': discount,
        'total': total,
        'coupon': coupon,
        'status': OrderStatus.placed.index,
      });
      for (final l in lines) {
        await tx.insert('order_items', {
          'order_id': id,
          'book_id': l.book.id,
          'title': l.book.title,
          'unit_price': l.book.price,
          'qty': l.qty,
        });
      }
      await tx.delete('cart_items', where: 'user_id = ?', whereArgs: [userId]);
    });
    return (await byId(id))!;
  }

  Future<int> countAll() async => Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM orders')) ?? 0;

  Future<double> revenue() async =>
      ((await _db.rawQuery('SELECT COALESCE(SUM(total),0) AS t FROM orders')).first['t'] as num).toDouble();

  Future<List<Order>> forUser(int userId) async {
    final rows = await _db.query(
      'orders',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'id DESC',
    );
    final out = <Order>[];
    for (final r in rows) {
      final items = await _db.query('order_items', where: 'order_id = ?', whereArgs: [r['id']]);
      out.add(Order.fromRow(r, items.map(OrderLine.fromRow).toList()));
    }
    return out;
  }

  Future<Order?> byId(int id) async {
    final r = await _db.query('orders', where: 'id = ?', whereArgs: [id]);
    if (r.isEmpty) return null;
    final items = await _db.query('order_items', where: 'order_id = ?', whereArgs: [id]);
    return Order.fromRow(r.first, items.map(OrderLine.fromRow).toList());
  }

  Future<void> advanceStatus(int id, OrderStatus s) =>
      _db.update('orders', {'status': s.index}, where: 'id = ?', whereArgs: [id]);

  /// إلغاء الطلب (حذف) — مسموح فقط إذا لم يُسلَّم
  Future<bool> cancel(int id) async {
    final n = await _db.delete(
      'orders',
      where: 'id = ? AND status != ?',
      whereArgs: [id, OrderStatus.delivered.index],
    );
    return n == 1;
  }
}

// ------------------------------------------------------------ Reviews
class ReviewRepo {
  Future<List<Review>> forBook(int bookId) async {
    final rows = await _db.rawQuery('''
      SELECT r.*, u.name AS user_name FROM reviews r
      JOIN users u ON u.id = r.user_id
      WHERE r.book_id = ? ORDER BY r.created_at DESC''', [bookId]);
    return rows.map(Review.fromRow).toList();
  }

  Future<Review?> mine(int bookId, int userId) async {
    final rows = await _db.rawQuery('''
      SELECT r.*, u.name AS user_name FROM reviews r
      JOIN users u ON u.id = r.user_id
      WHERE r.book_id = ? AND r.user_id = ?''', [bookId, userId]);
    return rows.isEmpty ? null : Review.fromRow(rows.first);
  }

  /// إنشاء أو تعديل (Upsert)
  Future<void> upsert(int bookId, int userId, int stars, String text) => _db.rawInsert('''
      INSERT INTO reviews(book_id, user_id, stars, text, created_at) VALUES(?, ?, ?, ?, ?)
      ON CONFLICT(book_id, user_id) DO UPDATE SET stars = excluded.stars, text = excluded.text, created_at = excluded.created_at''',
      [bookId, userId, stars, text.trim(), _now()]);

  Future<void> delete(int id) => _db.delete('reviews', where: 'id = ?', whereArgs: [id]);

  Future<int> countForBook(int bookId) async =>
      Sqflite.firstIntValue(await _db.rawQuery(
        'SELECT COUNT(*) FROM reviews WHERE book_id = ?',
        [bookId],
      )) ??
      0;
}
