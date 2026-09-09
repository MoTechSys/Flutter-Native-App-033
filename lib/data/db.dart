// ============================================================
// كِتابي - قاعدة البيانات المحلية (SQLite)
// الجداول: users, categories, books, cart_items, favorites,
//          orders, order_items, reviews
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'seed.dart';

class KitabiDb {
  KitabiDb._();
  static final KitabiDb instance = KitabiDb._();

  Database? _db;
  Database get db => _db!;

  /// مسار مخصص (للاختبارات: inMemoryDatabasePath)
  String? pathOverride;

  Future<void> open() async {
    if (_db != null) return;
    if (kIsWeb) databaseFactory = databaseFactoryFfiWeb;
    final path = pathOverride ?? '${await getDatabasesPath()}/kitabi.db';
    _db = await openDatabase(
      path,
      version: 1,
      onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
      onCreate: (d, _) async {
        await _schema(d);
        await seedCatalog(d);
      },
    );
  }

  Future<void> _schema(Database d) async {
    await d.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        phone TEXT,
        city TEXT,
        created_at TEXT NOT NULL
      )''');
    await d.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        slug TEXT NOT NULL,
        color INTEGER NOT NULL
      )''');
    await d.execute('''
      CREATE TABLE books(
        id INTEGER PRIMARY KEY,
        category_id INTEGER NOT NULL REFERENCES categories(id),
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        description TEXT,
        price REAL NOT NULL,
        old_price REAL,
        rating REAL NOT NULL,
        pages INTEGER NOT NULL,
        year INTEGER NOT NULL,
        cover TEXT NOT NULL,
        cover_color INTEGER NOT NULL,
        featured INTEGER NOT NULL DEFAULT 0
      )''');
    await d.execute('''
      CREATE TABLE cart_items(
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        book_id INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
        qty INTEGER NOT NULL,
        PRIMARY KEY(user_id, book_id)
      )''');
    await d.execute('''
      CREATE TABLE favorites(
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        book_id INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
        added_at TEXT NOT NULL,
        PRIMARY KEY(user_id, book_id)
      )''');
    await d.execute('''
      CREATE TABLE orders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        created_at TEXT NOT NULL,
        subtotal REAL NOT NULL,
        discount REAL NOT NULL,
        total REAL NOT NULL,
        coupon TEXT,
        status INTEGER NOT NULL
      )''');
    await d.execute('''
      CREATE TABLE order_items(
        order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
        book_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        unit_price REAL NOT NULL,
        qty INTEGER NOT NULL
      )''');
    await d.execute('''
      CREATE TABLE reviews(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        stars INTEGER NOT NULL,
        text TEXT,
        created_at TEXT NOT NULL,
        UNIQUE(book_id, user_id)
      )''');
  }

  /// للاختبارات فقط
  @visibleForTesting
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
