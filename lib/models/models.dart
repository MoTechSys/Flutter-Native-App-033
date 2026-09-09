// ============================================================
// كِتابي - نماذج البيانات
// ============================================================

/// دور المستخدم: عادي (يتسوّق) أو مدير (يدير الكتالوج أيضاً)
enum UserRole { customer, admin }

extension UserRoleX on UserRole {
  String get label => switch (this) {
    UserRole.customer => 'مستخدم',
    UserRole.admin => 'مدير المتجر',
  };
  String get hint => switch (this) {
    UserRole.customer => 'يتصفح الكتب ويشتري ويقيّم ويتابع طلباته',
    UserRole.admin => 'كل صلاحيات المستخدم + إضافة/تعديل/حذف الكتب والتصنيفات',
  };
}

class AppUser {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? city;
  final UserRole role;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.city,
    this.role = UserRole.customer,
  });

  bool get isAdmin => role == UserRole.admin;

  factory AppUser.fromRow(Map<String, Object?> r) => AppUser(
    id: r['id'] as int,
    name: (r['name'] ?? '') as String,
    email: (r['email'] ?? '') as String,
    phone: r['phone'] as String?,
    city: r['city'] as String?,
    role: ((r['role'] as int?) ?? 0) == 1 ? UserRole.admin : UserRole.customer,
  );
}

class Category {
  final int id;
  final String name;
  final String slug; // اسم أيقونة/لون
  final int color;

  const Category({
    required this.id,
    required this.name,
    required this.slug,
    required this.color,
  });

  factory Category.fromRow(Map<String, Object?> r) => Category(
    id: r['id'] as int,
    name: r['name'] as String,
    slug: r['slug'] as String,
    color: r['color'] as int,
  );

  Map<String, Object?> toRow() => {
    'id': id,
    'name': name,
    'slug': slug,
    'color': color,
  };
}

class Book {
  final int id;
  final int categoryId;
  final String title;
  final String author;
  final String description;
  final double price;
  final double? oldPrice; // للعروض
  final double rating; // 0..5
  final int pages;
  final int year;
  final String cover; // assets/covers/xxx.png
  final int coverColor; // لون احتياطي
  final bool featured;

  const Book({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.author,
    required this.description,
    required this.price,
    this.oldPrice,
    required this.rating,
    required this.pages,
    required this.year,
    required this.cover,
    required this.coverColor,
    this.featured = false,
  });

  /// هل الغلاف ملف على الجهاز (أضافه المدير) أم من Assets؟
  bool get coverIsFile => !cover.startsWith('assets/');

  Book copyWith({
    int? categoryId,
    String? title,
    String? author,
    String? description,
    double? price,
    double? oldPrice,
    bool clearOldPrice = false,
    double? rating,
    int? pages,
    int? year,
    String? cover,
    int? coverColor,
    bool? featured,
  }) => Book(
    id: id,
    categoryId: categoryId ?? this.categoryId,
    title: title ?? this.title,
    author: author ?? this.author,
    description: description ?? this.description,
    price: price ?? this.price,
    oldPrice: clearOldPrice ? null : (oldPrice ?? this.oldPrice),
    rating: rating ?? this.rating,
    pages: pages ?? this.pages,
    year: year ?? this.year,
    cover: cover ?? this.cover,
    coverColor: coverColor ?? this.coverColor,
    featured: featured ?? this.featured,
  );

  bool get hasDiscount => oldPrice != null && oldPrice! > price;
  int get discountPercent =>
      hasDiscount ? (((oldPrice! - price) / oldPrice!) * 100).round() : 0;

  factory Book.fromRow(Map<String, Object?> r) => Book(
    id: r['id'] as int,
    categoryId: r['category_id'] as int,
    title: r['title'] as String,
    author: r['author'] as String,
    description: (r['description'] ?? '') as String,
    price: (r['price'] as num).toDouble(),
    oldPrice: (r['old_price'] as num?)?.toDouble(),
    rating: (r['rating'] as num).toDouble(),
    pages: r['pages'] as int,
    year: r['year'] as int,
    cover: r['cover'] as String,
    coverColor: r['cover_color'] as int,
    featured: (r['featured'] as int) == 1,
  );

  Map<String, Object?> toRow() => {
    'id': id,
    'category_id': categoryId,
    'title': title,
    'author': author,
    'description': description,
    'price': price,
    'old_price': oldPrice,
    'rating': rating,
    'pages': pages,
    'year': year,
    'cover': cover,
    'cover_color': coverColor,
    'featured': featured ? 1 : 0,
  };
}

class CartLine {
  final Book book;
  final int qty;
  const CartLine({required this.book, required this.qty});
  double get total => book.price * qty;
  CartLine copyWith({int? qty}) => CartLine(book: book, qty: qty ?? this.qty);
}

enum OrderStatus { placed, processing, delivered }

extension OrderStatusX on OrderStatus {
  String get label => switch (this) {
    OrderStatus.placed => 'تم الطلب',
    OrderStatus.processing => 'قيد التجهيز',
    OrderStatus.delivered => 'تم التسليم',
  };
}

class Order {
  final int id;
  final int userId;
  final DateTime createdAt;
  final double subtotal;
  final double discount;
  final double total;
  final String? coupon;
  final OrderStatus status;
  final List<OrderLine> lines;

  const Order({
    required this.id,
    required this.userId,
    required this.createdAt,
    required this.subtotal,
    required this.discount,
    required this.total,
    this.coupon,
    required this.status,
    this.lines = const [],
  });

  int get itemCount => lines.fold(0, (a, l) => a + l.qty);

  factory Order.fromRow(Map<String, Object?> r, [List<OrderLine> lines = const []]) =>
      Order(
        id: r['id'] as int,
        userId: r['user_id'] as int,
        createdAt: DateTime.parse(r['created_at'] as String),
        subtotal: (r['subtotal'] as num).toDouble(),
        discount: (r['discount'] as num).toDouble(),
        total: (r['total'] as num).toDouble(),
        coupon: r['coupon'] as String?,
        status: OrderStatus.values[r['status'] as int],
        lines: lines,
      );
}

class OrderLine {
  final int bookId;
  final String title;
  final double unitPrice;
  final int qty;
  const OrderLine({
    required this.bookId,
    required this.title,
    required this.unitPrice,
    required this.qty,
  });
  double get total => unitPrice * qty;

  factory OrderLine.fromRow(Map<String, Object?> r) => OrderLine(
    bookId: r['book_id'] as int,
    title: r['title'] as String,
    unitPrice: (r['unit_price'] as num).toDouble(),
    qty: r['qty'] as int,
  );
}

class Review {
  final int id;
  final int bookId;
  final int userId;
  final String userName;
  final int stars; // 1..5
  final String text;
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.bookId,
    required this.userId,
    required this.userName,
    required this.stars,
    required this.text,
    required this.createdAt,
  });

  factory Review.fromRow(Map<String, Object?> r) => Review(
    id: r['id'] as int,
    bookId: r['book_id'] as int,
    userId: r['user_id'] as int,
    userName: (r['user_name'] ?? '') as String,
    stars: r['stars'] as int,
    text: (r['text'] ?? '') as String,
    createdAt: DateTime.parse(r['created_at'] as String),
  );
}
