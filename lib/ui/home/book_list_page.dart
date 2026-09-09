// ============================================================
// كِتابي - قائمة الكتب / البحث (شبكة + فلترة + ترتيب)
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../models/models.dart';
import '../../state/store_state.dart';
import '../shared/widgets.dart';
import 'book_detail_page.dart';

class BookListPage extends StatefulWidget {
  final String title;
  final int? categoryId;
  final bool featuredOnly;
  final BookSort sort;
  final bool autofocusSearch;

  const BookListPage({
    super.key,
    required this.title,
    this.categoryId,
    this.featuredOnly = false,
    this.sort = BookSort.relevance,
    this.autofocusSearch = false,
  });

  @override
  State<BookListPage> createState() => _BookListPageState();
}

class _BookListPageState extends State<BookListPage> {
  final _q = TextEditingController();
  late BookSort _sort = widget.sort;
  late int? _cat = widget.categoryId;
  double? _maxPrice;

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogState>();
    var list = catalog.search(_q.text, categoryId: _cat, maxPrice: _maxPrice, sort: _sort);
    if (widget.featuredOnly) list = list.where((b) => b.featured).toList();
    final cats = catalog.categories;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          PopupMenuButton<BookSort>(
            tooltip: 'ترتيب',
            icon: const Icon(Icons.swap_vert),
            color: Palette.nightSoft,
            onSelected: (s) => setState(() => _sort = s),
            itemBuilder: (_) => BookSort.values
                .map((s) => PopupMenuItem(
                      value: s,
                      child: Row(
                        children: [
                          Icon(s == _sort ? Icons.radio_button_checked : Icons.radio_button_off, size: 16, color: Palette.gold),
                          const SizedBox(width: 8),
                          Text(s.label),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: TextField(
                controller: _q,
                autofocus: widget.autofocusSearch,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'ابحث بالعنوان أو المؤلف...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _q.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(_q.clear),
                        ),
                ),
              ),
            ),
            // فلاتر
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (widget.categoryId == null) ...[
                    ChoiceChip(label: const Text('الكل'), selected: _cat == null, onSelected: (_) => setState(() => _cat = null)),
                    const SizedBox(width: 6),
                    for (final c in cats) ...[
                      ChoiceChip(label: Text(c.name), selected: _cat == c.id, onSelected: (_) => setState(() => _cat = c.id)),
                      const SizedBox(width: 6),
                    ],
                  ],
                  for (final p in [50.0, 80.0, 120.0]) ...[
                    FilterChip(
                      label: Text('≤ ${p.toInt()} ر.س'),
                      selected: _maxPrice == p,
                      onSelected: (v) => setState(() => _maxPrice = v ? p : null),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Text('${list.length} نتيجة', style: const TextStyle(color: Palette.ivoryDim, fontSize: 12)),
                  const Spacer(),
                  Text(_sort.label, style: const TextStyle(color: Palette.gold, fontSize: 12)),
                ],
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const EmptyView(icon: Icons.search_off, title: 'لا توجد نتائج', subtitle: 'جرّب كلمة أخرى أو أزل الفلاتر')
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.56,
                      ),
                      itemCount: list.length,
                      itemBuilder: (_, i) => BookGridCard(book: list[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// بطاقة كتاب في الشبكة (تُستخدم أيضاً في المفضلة)
class BookGridCard extends StatelessWidget {
  final Book book;
  const BookGridCard({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    final fav = context.watch<FavoritesState>();
    final cart = context.watch<CartState>();
    final inCart = cart.contains(book.id);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailPage(book: book))),
      child: LayoutBuilder(
        builder: (context, c) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                BookCover(book: book, width: c.maxWidth, height: c.maxHeight - 82, radius: 10),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () async {
                        final added = await context.read<FavoritesState>().toggle(book);
                        if (context.mounted) notify(context, added ? 'أُضيف إلى المفضلة' : 'أُزيل من المفضلة');
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(fav.isFav(book.id) ? Icons.favorite : Icons.favorite_border, size: 16, color: fav.isFav(book.id) ? Palette.danger : Palette.ivory),
                      ),
                    ),
                  ),
                ),
                if (book.hasDiscount) Positioned(top: 6, right: 6, child: DiscountRibbon(percent: book.discountPercent)),
              ],
            ),
            const SizedBox(height: 8),
            Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Palette.ivoryDim, fontSize: 11)),
            const Spacer(),
            Row(
              children: [
                Expanded(child: PriceTag(book: book, size: 13)),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
                    await context.read<CartState>().add(book);
                    if (context.mounted) notify(context, 'أُضيف "${book.title}" إلى السلة', icon: Icons.shopping_bag);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: inCart ? Palette.gold : Palette.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(inCart ? Icons.check : Icons.add_shopping_cart, size: 16, color: inCart ? Palette.night : Palette.gold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
