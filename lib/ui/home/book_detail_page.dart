// ============================================================
// كِتابي - تفاصيل الكتاب (شاشة واحدة) + ورقة سفلية للوصف والمراجعات
//   المراجعات: إضافة / تعديل / حذف (CRUD يملكه المستخدم)
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../data/repos/repos.dart';
import '../../models/models.dart';
import '../../state/session.dart';
import '../../state/store_state.dart';
import '../shared/widgets.dart';
import '../shell.dart';

class BookDetailPage extends StatefulWidget {
  final Book book;
  const BookDetailPage({super.key, required this.book});
  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  final _reviews = ReviewRepo();
  int _reviewCount = 0;
  int _qty = 1;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    final n = await _reviews.countForBook(widget.book.id);
    if (mounted) setState(() => _reviewCount = n);
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.book;
    final catalog = context.watch<CatalogState>();
    final fav = context.watch<FavoritesState>();
    final cart = context.watch<CartState>();
    final cat = catalog.category(b.categoryId);
    final isFav = fav.isFav(b.id);
    final inCartQty = cart.qtyOf(b.id);

    return Scaffold(
      body: Stack(
        children: [
          // هالة لونية خلف الغلاف
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [Color(b.coverColor).withValues(alpha: 0.35), Colors.transparent]),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // شريط علوي
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: Row(
                    children: [
                      IconButton(icon: const Icon(Icons.arrow_forward), onPressed: () => Navigator.pop(context)),
                      const Spacer(),
                      IconButton(
                        tooltip: 'المفضلة',
                        icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Palette.danger : Palette.ivory),
                        onPressed: () async {
                          final added = await context.read<FavoritesState>().toggle(b);
                          if (context.mounted) notify(context, added ? 'أُضيف إلى المفضلة' : 'أُزيل من المفضلة');
                        },
                      ),
                    ],
                  ),
                ),
                // الغلاف
                Expanded(
                  flex: 5,
                  child: Center(child: BookCover(book: b, width: 150, radius: 12)),
                ),
                // المعلومات
                Expanded(
                  flex: 6,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                    decoration: const BoxDecoration(
                      color: Palette.nightSoft,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                      border: Border(top: BorderSide(color: Palette.line)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (cat != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(color: Color(cat.color).withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)),
                                child: Text(cat.name, style: const TextStyle(fontSize: 11)),
                              ),
                            const Spacer(),
                            RatingStars(value: b.rating),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(b.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 21)),
                        Text(b.author, style: const TextStyle(color: Palette.ivoryDim)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 14,
                          runSpacing: 4,
                          children: [
                            _Meta(icon: Icons.menu_book_outlined, text: '${b.pages} صفحة'),
                            _Meta(icon: Icons.calendar_today_outlined, text: '${b.year}'),
                            _Meta(icon: Icons.rate_review_outlined, text: '$_reviewCount مراجعة'),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // الوصف (سطران) + زر المزيد
                        Expanded(
                          child: InkWell(
                            onTap: () => _openSheet(context, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(b.description, overflow: TextOverflow.fade, style: const TextStyle(color: Palette.ivoryDim, height: 1.55, fontSize: 13)),
                                ),
                                Row(
                                  children: [
                                    Flexible(
                                      child: TextButton.icon(
                                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                                        onPressed: () => _openSheet(context, 0),
                                        icon: const Icon(Icons.unfold_more, size: 16),
                                        label: const Text('الوصف الكامل', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                      ),
                                    ),
                                    Flexible(
                                      child: TextButton.icon(
                                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                                        onPressed: () => _openSheet(context, 1),
                                        icon: const Icon(Icons.reviews_outlined, size: 16),
                                        label: const Text('المراجعات', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        // السعر + الكمية + الإضافة
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('السعر', style: TextStyle(color: Palette.ivoryDim, fontSize: 11)),
                                  PriceTag(book: b, size: 20),
                                ],
                              ),
                            ),
                            _QtyPicker(qty: _qty, onChanged: (q) => setState(() => _qty = q)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: FilledButton.icon(
                                onPressed: () async {
                                  await context.read<CartState>().add(b, qty: _qty);
                                  if (context.mounted) notify(context, 'أُضيف $_qty × "${b.title}" إلى السلة', icon: Icons.shopping_bag);
                                },
                                icon: const Icon(Icons.add_shopping_cart),
                                label: Text(inCartQty > 0 ? 'أضف أيضاً (في السلة $inCartQty)' : 'أضف إلى السلة'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: OutlinedButton(
                                onPressed: () async {
                                  if (inCartQty == 0) await context.read<CartState>().add(b, qty: _qty);
                                  if (!context.mounted) return;
                                  // إلى جذر التبويب ثم التبويب "السلة"
                                  Navigator.of(context).popUntil((r) => r.isFirst);
                                  context.read<ShellController>().go(ShellTab.cart);
                                },
                                child: const Text('اشترِ الآن'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSheet(BuildContext context, int tab) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, scroll) => _DetailsSheet(book: widget.book, initialTab: tab, scroll: scroll),
      ),
    );
    _loadCount();
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: Palette.gold),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(fontSize: 12, color: Palette.ivoryDim)),
    ],
  );
}

class _QtyPicker extends StatelessWidget {
  final int qty;
  final ValueChanged<int> onChanged;
  const _QtyPicker({required this.qty, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(border: Border.all(color: Palette.line), borderRadius: BorderRadius.circular(12)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(visualDensity: VisualDensity.compact, onPressed: qty > 1 ? () => onChanged(qty - 1) : null, icon: const Icon(Icons.remove)),
        Text('$qty', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        IconButton(visualDensity: VisualDensity.compact, onPressed: qty < 10 ? () => onChanged(qty + 1) : null, icon: const Icon(Icons.add)),
      ],
    ),
  );
}

// ------------------------------------------------------------ Sheet: description + reviews
class _DetailsSheet extends StatefulWidget {
  final Book book;
  final int initialTab;
  final ScrollController scroll;
  const _DetailsSheet({required this.book, required this.initialTab, required this.scroll});
  @override
  State<_DetailsSheet> createState() => _DetailsSheetState();
}

class _DetailsSheetState extends State<_DetailsSheet> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
  final _repo = ReviewRepo();
  List<Review> _list = [];
  Review? _mine;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = context.read<Session>().uid;
    final list = await _repo.forBook(widget.book.id);
    final mine = await _repo.mine(widget.book.id, uid);
    if (mounted) {
      setState(() {
        _list = list;
        _mine = mine;
      });
    }
  }

  Future<void> _edit() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ReviewDialog(book: widget.book, existing: _mine),
    );
    if (saved == true) {
      await _load();
      if (mounted) notify(context, _mine == null ? 'تم نشر مراجعتك' : 'تم تحديث مراجعتك');
    }
  }

  Future<void> _delete() async {
    if (_mine == null) return;
    if (!await confirm(context, title: 'حذف المراجعة', message: 'هل تريد حذف مراجعتك لهذا الكتاب؟', okLabel: 'حذف', destructive: true)) return;
    await _repo.delete(_mine!.id);
    await _load();
    if (mounted) notify(context, 'تم حذف المراجعة');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(width: 44, height: 4, decoration: BoxDecoration(color: Palette.line, borderRadius: BorderRadius.circular(2))),
        TabBar(
          controller: _tabs,
          indicatorColor: Palette.gold,
          labelColor: Palette.gold,
          unselectedLabelColor: Palette.ivoryDim,
          tabs: [const Tab(text: 'الوصف'), Tab(text: 'المراجعات (${_list.length})')],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              ListView(
                controller: widget.scroll,
                padding: const EdgeInsets.all(20),
                children: [
                  Text(widget.book.title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(widget.book.author, style: const TextStyle(color: Palette.ivoryDim)),
                  const Divider(height: 24),
                  Text(widget.book.description, style: const TextStyle(height: 1.8, fontSize: 15)),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _Fact('الصفحات', '${widget.book.pages}'),
                      _Fact('سنة النشر', '${widget.book.year}'),
                      _Fact('التقييم', widget.book.rating.toStringAsFixed(1)),
                      _Fact('السعر', fmtPrice(widget.book.price)),
                    ],
                  ),
                ],
              ),
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: _mine == null
                        ? FilledButton.icon(onPressed: _edit, icon: const Icon(Icons.rate_review), label: const Text('أضف مراجعتك'))
                        : Row(
                            children: [
                              Expanded(child: OutlinedButton.icon(onPressed: _edit, icon: const Icon(Icons.edit_outlined), label: const Text('تعديل مراجعتي'))),
                              const SizedBox(width: 10),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(foregroundColor: Palette.danger, side: const BorderSide(color: Palette.danger), minimumSize: const Size(50, 50)),
                                onPressed: _delete,
                                child: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                  ),
                  Expanded(
                    child: _list.isEmpty
                        ? const EmptyView(icon: Icons.reviews_outlined, title: 'لا مراجعات بعد', subtitle: 'كن أول من يشارك رأيه في هذا الكتاب')
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _list.length,
                            separatorBuilder: (_, _) => const Divider(height: 18),
                            itemBuilder: (_, i) {
                              final r = _list[i];
                              final mine = r.id == _mine?.id;
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: mine ? Palette.gold : Palette.walnutLight,
                                    child: Text(r.userName.isEmpty ? '؟' : r.userName.characters.first, style: TextStyle(color: mine ? Palette.night : Palette.ivory, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(child: Text(mine ? '${r.userName} (أنت)' : r.userName, style: const TextStyle(fontWeight: FontWeight.w700))),
                                            RatingStars(value: r.stars.toDouble(), size: 13, showNumber: false),
                                          ],
                                        ),
                                        Text(fmtDate(r.createdAt), style: const TextStyle(fontSize: 11, color: Palette.ivoryDim)),
                                        if (r.text.isNotEmpty) ...[const SizedBox(height: 4), Text(r.text, style: const TextStyle(height: 1.5))],
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  final String k, v;
  const _Fact(this.k, this.v);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: Palette.night, borderRadius: BorderRadius.circular(10), border: Border.all(color: Palette.line)),
    child: Column(
      children: [
        Text(v, style: const TextStyle(fontWeight: FontWeight.w800, color: Palette.gold)),
        Text(k, style: const TextStyle(fontSize: 11, color: Palette.ivoryDim)),
      ],
    ),
  );
}

class _ReviewDialog extends StatefulWidget {
  final Book book;
  final Review? existing;
  const _ReviewDialog({required this.book, this.existing});
  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  late int _stars = widget.existing?.stars ?? 5;
  late final _text = TextEditingController(text: widget.existing?.text ?? '');
  final _form = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? 'مراجعة جديدة' : 'تعديل المراجعة'),
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  onPressed: () => setState(() => _stars = i),
                  icon: Icon(i <= _stars ? Icons.star_rounded : Icons.star_outline_rounded, color: Palette.gold, size: 30),
                ),
            ],
          ),
          TextFormField(
            controller: _text,
            maxLines: 3,
            maxLength: 300,
            decoration: const InputDecoration(labelText: 'رأيك في الكتاب'),
            validator: (v) => (v ?? '').trim().length < 5 ? 'اكتب 5 أحرف على الأقل' : null,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(90, 40)),
        onPressed: () async {
          if (!_form.currentState!.validate()) return;
          final uid = context.read<Session>().uid;
          await ReviewRepo().upsert(widget.book.id, uid, _stars, _text.text);
          if (context.mounted) Navigator.pop(context, true);
        },
        child: const Text('نشر'),
      ),
    ],
  );
}
