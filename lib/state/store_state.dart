// ============================================================
// كِتابي - حالة المتجر (Provider)
//   CatalogState   : التصنيفات والكتب والبحث/الفلترة
//   CartState      : سلة المشتريات + كوبون + إتمام الطلب
//   FavoritesState : المفضلة
// ============================================================

import 'package:flutter/foundation.dart' hide Category;

import '../data/repos/repos.dart';
import '../models/models.dart';

// ------------------------------------------------------------ Catalog
class CatalogState extends ChangeNotifier {
  final _repo = CatalogRepo();
  List<Category> _categories = [];
  List<Book> _books = [];
  bool _loaded = false;

  List<Category> get categories => _categories;
  List<Book> get books => _books;
  bool get loaded => _loaded;

  Future<void> load() async {
    _categories = await _repo.categories();
    _books = await _repo.books();
    _loaded = true;
    notifyListeners();
  }

  Category? category(int id) => _categories.where((c) => c.id == id).firstOrNull;
  Book? book(int id) => _books.where((b) => b.id == id).firstOrNull;

  List<Book> get featured => _books.where((b) => b.featured).toList();
  List<Book> get onSale => _books.where((b) => b.hasDiscount).toList();
  List<Book> get topRated =>
      [..._books]..sort((a, b) => b.rating.compareTo(a.rating));
  List<Book> byCategory(int id) => _books.where((b) => b.categoryId == id).toList();

  /// بحث + فلترة (تصنيف اختياري، حد أقصى للسعر اختياري)
  List<Book> search(String q, {int? categoryId, double? maxPrice, BookSort sort = BookSort.relevance}) {
    final t = q.trim().toLowerCase();
    var out = _books.where((b) {
      if (categoryId != null && b.categoryId != categoryId) return false;
      if (maxPrice != null && b.price > maxPrice) return false;
      if (t.isEmpty) return true;
      return b.title.toLowerCase().contains(t) || b.author.toLowerCase().contains(t);
    }).toList();
    switch (sort) {
      case BookSort.relevance:
        break;
      case BookSort.priceAsc:
        out.sort((a, b) => a.price.compareTo(b.price));
      case BookSort.priceDesc:
        out.sort((a, b) => b.price.compareTo(a.price));
      case BookSort.rating:
        out.sort((a, b) => b.rating.compareTo(a.rating));
      case BookSort.newest:
        out.sort((a, b) => b.year.compareTo(a.year));
    }
    return out;
  }
}

enum BookSort { relevance, priceAsc, priceDesc, rating, newest }

extension BookSortX on BookSort {
  String get label => switch (this) {
    BookSort.relevance => 'الأكثر صلة',
    BookSort.priceAsc => 'السعر: من الأقل',
    BookSort.priceDesc => 'السعر: من الأعلى',
    BookSort.rating => 'الأعلى تقييماً',
    BookSort.newest => 'الأحدث',
  };
}

// ------------------------------------------------------------ Cart
class Coupon {
  final String code;
  final int percent;
  const Coupon(this.code, this.percent);
}

class CartState extends ChangeNotifier {
  final _repo = CartRepo();
  final _orders = OrderRepo();

  /// كوبونات المحاكاة
  static const coupons = [Coupon('KITABI10', 10), Coupon('READ20', 20), Coupon('WELCOME15', 15)];

  int _uid = 0;
  List<CartLine> _lines = [];
  Coupon? _coupon;

  List<CartLine> get lines => _lines;
  Coupon? get coupon => _coupon;
  int get count => _lines.fold(0, (a, l) => a + l.qty);
  bool get isEmpty => _lines.isEmpty;
  double get subtotal => _lines.fold(0, (a, l) => a + l.total);
  double get discount => _coupon == null ? 0 : subtotal * _coupon!.percent / 100;
  double get total => subtotal - discount;
  bool contains(int bookId) => _lines.any((l) => l.book.id == bookId);
  int qtyOf(int bookId) => _lines.where((l) => l.book.id == bookId).firstOrNull?.qty ?? 0;

  Future<void> bind(int uid) async {
    _uid = uid;
    _coupon = null;
    await _reload();
  }

  void unbind() {
    _uid = 0;
    _lines = [];
    _coupon = null;
    notifyListeners();
  }

  Future<void> _reload() async {
    _lines = _uid == 0 ? [] : await _repo.lines(_uid);
    notifyListeners();
  }

  Future<void> add(Book b, {int qty = 1}) async {
    await _repo.add(_uid, b.id, qty: qty);
    await _reload();
  }

  Future<void> setQty(Book b, int qty) async {
    await _repo.setQty(_uid, b.id, qty);
    await _reload();
  }

  Future<void> remove(Book b) async {
    await _repo.remove(_uid, b.id);
    await _reload();
  }

  Future<void> clear() async {
    await _repo.clear(_uid);
    _coupon = null;
    await _reload();
  }

  /// يُعيد رسالة خطأ أو null عند النجاح
  String? applyCoupon(String code) {
    final c = code.trim().toUpperCase();
    final found = coupons.where((k) => k.code == c).firstOrNull;
    if (found == null) return 'كود الخصم غير صالح';
    _coupon = found;
    notifyListeners();
    return null;
  }

  void removeCoupon() {
    _coupon = null;
    notifyListeners();
  }

  Future<Order> checkout() async {
    final order = await _orders.placeOrder(
      _uid,
      _lines,
      discount: discount,
      coupon: _coupon?.code,
    );
    _coupon = null;
    await _reload();
    return order;
  }
}

// ------------------------------------------------------------ Favorites
class FavoritesState extends ChangeNotifier {
  final _repo = FavoriteRepo();
  int _uid = 0;
  Set<int> _ids = {};
  List<Book> _books = [];

  Set<int> get ids => _ids;
  List<Book> get books => _books;
  int get count => _ids.length;
  bool isFav(int bookId) => _ids.contains(bookId);

  Future<void> bind(int uid) async {
    _uid = uid;
    await _reload();
  }

  void unbind() {
    _uid = 0;
    _ids = {};
    _books = [];
    notifyListeners();
  }

  Future<void> _reload() async {
    if (_uid == 0) {
      _ids = {};
      _books = [];
    } else {
      _ids = await _repo.ids(_uid);
      _books = await _repo.books(_uid);
    }
    notifyListeners();
  }

  /// يُعيد true إذا أُضيف، false إذا أُزيل
  Future<bool> toggle(Book b) async {
    final added = await _repo.toggle(_uid, b.id);
    await _reload();
    return added;
  }

  Future<void> clear() async {
    await _repo.clear(_uid);
    await _reload();
  }
}
