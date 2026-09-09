// ============================================================
// كِتابي - الرئيسية (ثابتة: تملأ الشاشة بلا تمرير عمودي)
//   [رأس: ترحيب + حسابي]  [بحث]  [بانر عرض]  [شريط تصنيفات]
//   [رف "اختيارات كِتابي" أفقي]  [شريط "الأعلى تقييماً" أفقي]
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../models/models.dart';
import '../../state/session.dart';
import '../../state/store_state.dart';
import '../profile/profile_page.dart';
import '../shared/widgets.dart';
import 'book_detail_page.dart';
import 'book_list_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final catalog = context.watch<CatalogState>();
    final name = session.user?.name.split(' ').first ?? '';
    final featured = catalog.featured;
    final sale = catalog.onSale;
    final banner = sale.isNotEmpty
        ? sale.first
        : (featured.isNotEmpty ? featured.first : null);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            // توزيع الارتفاع بحيث لا تحتاج الشاشة للتمرير
            final h = c.maxHeight;
            final shelfH = (h * 0.34).clamp(200.0, 270.0);
            final stripH = (h * 0.15).clamp(96.0, 120.0);
            return Column(
              children: [
                _Header(name: name),
                const SizedBox(height: 8),
                const _SearchBar(),
                const SizedBox(height: 10),
                if (banner != null) _Banner(book: banner),
                const SizedBox(height: 10),
                const _CategoryStrip(),
                const SizedBox(height: 6),
                SectionTitle(
                  title: 'اختيارات كِتابي',
                  onAction: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BookListPage(
                        title: 'اختيارات كِتابي',
                        featuredOnly: true,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: shelfH,
                  child: _Shelf(books: featured),
                ),
                SectionTitle(
                  title: 'الأعلى تقييماً',
                  onAction: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BookListPage(
                        title: 'الأعلى تقييماً',
                        sort: BookSort.rating,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SizedBox(
                    height: stripH,
                    child: _TopRatedStrip(
                      books: catalog.topRated.take(8).toList(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ Header
class _Header extends StatelessWidget {
  final String name;
  const _Header({required this.name});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
    child: Row(
      children: [
        Semantics(
          label: 'حسابي',
          button: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfilePage()),
            ),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Palette.gold, Palette.goldDim],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Palette.gold.withValues(alpha: 0.3),
                    blurRadius: 10,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                name.isEmpty ? '؟' : name.characters.first,
                style: const TextStyle(
                  color: Palette.night,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(),
                style: const TextStyle(color: Palette.ivoryDim, fontSize: 12),
              ),
              Text(
                name.isEmpty ? 'قارئ كِتابي' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
        Text(
          'كِتابي',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Palette.gold,
            fontSize: 22,
          ),
        ),
      ],
    ),
  );

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'صباح الخير،';
    if (h < 18) return 'مساء الخير،';
    return 'مساء النور،';
  }
}

// ------------------------------------------------------------ Search
class _SearchBar extends StatelessWidget {
  const _SearchBar();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const BookListPage(title: 'بحث', autofocusSearch: true),
        ),
      ),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Palette.nightSoft,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Palette.gold.withValues(alpha: 0.35)),
        ),
        child: const Row(
          children: [
            Icon(Icons.search, color: Palette.gold),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'ابحث عن كتاب أو مؤلف...',
                style: TextStyle(color: Palette.ivoryDim),
              ),
            ),
            Icon(Icons.tune, color: Palette.ivoryDim, size: 20),
          ],
        ),
      ),
    ),
  );
}

// ------------------------------------------------------------ Banner
class _Banner extends StatelessWidget {
  final Book book;
  const _Banner({required this.book});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BookDetailPage(book: book)),
      ),
      child: Container(
        height: 108,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Palette.walnut, Palette.nightSoft],
          ),
          border: Border.all(color: Palette.gold.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            BookCover(book: book, width: 56, radius: 6, hero: false),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (book.hasDiscount)
                    DiscountRibbon(percent: book.discountPercent)
                  else
                    const Text(
                      'اختيار المحرر',
                      style: TextStyle(color: Palette.gold, fontSize: 11),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontFamily: AppText.serif,
                      fontSize: 15,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    book.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Palette.ivoryDim,
                      fontSize: 11.5,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  PriceTag(book: book, size: 13),
                ],
              ),
            ),
            const Icon(Icons.chevron_left, color: Palette.gold),
          ],
        ),
      ),
    ),
  );
}

// ------------------------------------------------------------ Categories strip
class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip();
  @override
  Widget build(BuildContext context) {
    final cats = context.watch<CatalogState>().categories;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: cats.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = cats[i];
          return ActionChip(
            avatar: Icon(
              categoryIcon(c.slug),
              size: 16,
              color: Color(c.color).withValues(alpha: 1),
            ),
            label: Text(c.name),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BookListPage(title: c.name, categoryId: c.id),
              ),
            ),
          );
        },
      ),
    );
  }
}

IconData categoryIcon(String slug) => switch (slug) {
  'novel' => Icons.auto_stories_outlined,
  'growth' => Icons.self_improvement,
  'tech' => Icons.code,
  'history' => Icons.account_balance_outlined,
  'kids' => Icons.child_care,
  'science' => Icons.science_outlined,
  _ => Icons.book_outlined,
};

// ------------------------------------------------------------ Shelf (wooden)
class _Shelf extends StatelessWidget {
  final List<Book> books;
  const _Shelf({required this.books});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final coverH = c.maxHeight - 74; // مساحة للعنوان + السعر + الرف
      final coverW = coverH / 1.45;
      return Stack(
        children: [
          // خط الرف الخشبي
          Positioned(
            left: 0,
            right: 0,
            top: coverH + 4,
            child: Container(
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: const LinearGradient(
                  colors: [Palette.walnutLight, Palette.walnut],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
          ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: books.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (_, i) =>
                _ShelfItem(book: books[i], coverW: coverW, coverH: coverH),
          ),
        ],
      );
    },
  );
}

class _ShelfItem extends StatelessWidget {
  final Book book;
  final double coverW, coverH;
  const _ShelfItem({
    required this.book,
    required this.coverW,
    required this.coverH,
  });
  @override
  Widget build(BuildContext context) {
    final fav = context.watch<FavoritesState>();
    return SizedBox(
      width: coverW,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BookDetailPage(book: book)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                BookCover(book: book, width: coverW, height: coverH, radius: 8),
                Positioned(
                  top: 6,
                  left: 6,
                  child: _HeartButton(book: book, active: fav.isFav(book.id)),
                ),
                if (book.hasDiscount)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: DiscountRibbon(percent: book.discountPercent),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    fmtPrice(book.price),
                    style: const TextStyle(
                      color: Palette.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Icon(Icons.star_rounded, size: 12, color: Palette.gold),
                Text(
                  book.rating.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 11, color: Palette.ivoryDim),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeartButton extends StatelessWidget {
  final Book book;
  final bool active;
  const _HeartButton({required this.book, required this.active});
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black54,
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: () async {
        final added = await context.read<FavoritesState>().toggle(book);
        if (context.mounted) {
          notify(
            context,
            added ? 'أُضيف إلى المفضلة' : 'أُزيل من المفضلة',
            icon: added ? Icons.favorite : Icons.favorite_border,
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          active ? Icons.favorite : Icons.favorite_border,
          size: 16,
          color: active ? Palette.danger : Palette.ivory,
        ),
      ),
    ),
  );
}

// ------------------------------------------------------------ Top rated strip
class _TopRatedStrip extends StatelessWidget {
  final List<Book> books;
  const _TopRatedStrip({required this.books});
  @override
  Widget build(BuildContext context) => ListView.separated(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    itemCount: books.length,
    separatorBuilder: (_, _) => const SizedBox(width: 10),
    itemBuilder: (_, i) {
      final b = books[i];
      return InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BookDetailPage(book: b)),
        ),
        child: Container(
          width: 210,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Palette.nightSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Palette.line),
          ),
          child: Row(
            children: [
              BookCover(book: b, width: 44, radius: 5, hero: false),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      b.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Palette.ivoryDim,
                      ),
                    ),
                    const SizedBox(height: 2),
                    RatingStars(value: b.rating, size: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
