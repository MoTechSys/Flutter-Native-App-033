// ============================================================
// كِتابي - لوحة إدارة المتجر (للمدير فقط)
//   تبويب الكتب     : بحث + قائمة + إضافة/تعديل/حذف (سحب)
//   تبويب التصنيفات : إضافة/تعديل/حذف (يُمنع حذف تصنيف فيه كتب)
//   تبويب الإحصاءات : أعداد + إيراد + الأكثر مبيعاً
// كل عملية تُنفَّذ مباشرة على SQLite ثم تظهر فوراً في المتجر.
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../data/repos/repos.dart';
import '../../models/models.dart';
import '../../state/store_state.dart';
import '../home/book_detail_page.dart';
import '../home/home_page.dart' show kCategoryIcons, categoryIcon;
import '../shared/widgets.dart';
import 'book_form_page.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المتجر'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Palette.gold,
          labelColor: Palette.gold,
          unselectedLabelColor: Palette.ivoryDim,
          tabs: const [
            Tab(icon: Icon(Icons.menu_book_outlined), text: 'الكتب'),
            Tab(icon: Icon(Icons.category_outlined), text: 'التصنيفات'),
            Tab(icon: Icon(Icons.insights_outlined), text: 'الإحصاءات'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabs,
          children: const [_BooksTab(), _CategoriesTab(), _StatsTab()],
        ),
      ),
    );
  }
}

// ============================================================ الكتب
class _BooksTab extends StatefulWidget {
  const _BooksTab();
  @override
  State<_BooksTab> createState() => _BooksTabState();
}

class _BooksTabState extends State<_BooksTab> {
  final _q = TextEditingController();
  int? _cat;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _delete(Book b) async {
    final ok = await confirm(
      context,
      title: 'حذف الكتاب',
      message: 'سيُحذف "${b.title}" نهائياً من المتجر ومن سلال ومفضلات المستخدمين. هل أنت متأكد؟',
      okLabel: 'حذف',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await context.read<CatalogState>().deleteBook(b.id);
    if (mounted) notify(context, 'تم حذف "${b.title}"', icon: Icons.delete_outline);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogState>();
    final books = catalog.search(_q.text, categoryId: _cat);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'admin-add-book',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BookFormPage())),
        icon: const Icon(Icons.add),
        label: const Text('إضافة كتاب'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              controller: _q,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'ابحث في ${catalog.books.length} كتاب...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _q.text.isEmpty
                    ? null
                    : IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _q.clear())),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                ChoiceChip(label: const Text('الكل'), selected: _cat == null, onSelected: (_) => setState(() => _cat = null)),
                for (final c in catalog.categories) ...[
                  const SizedBox(width: 6),
                  ChoiceChip(label: Text(c.name), selected: _cat == c.id, onSelected: (_) => setState(() => _cat = c.id)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: books.isEmpty
                ? const EmptyView(icon: Icons.menu_book_outlined, title: 'لا توجد كتب', subtitle: 'أضف كتاباً جديداً بالزر أدناه')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                    itemCount: books.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final b = books[i];
                      final cat = catalog.category(b.categoryId);
                      return Dismissible(
                        key: ValueKey('admin-book-${b.id}'),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) async {
                          await _delete(b);
                          return false; // القائمة تتحدث من الحالة
                        },
                        background: Container(
                          alignment: AlignmentDirectional.centerEnd,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(color: Palette.danger.withValues(alpha: .25), borderRadius: BorderRadius.circular(14)),
                          child: const Icon(Icons.delete_outline, color: Palette.danger),
                        ),
                        child: Card(
                          child: ListTile(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailPage(book: b))),
                            leading: BookCover(book: b, width: 40, radius: 6, hero: false),
                            title: Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              '${b.author} • ${cat?.name ?? '—'} • ${fmtPrice(b.price)}${b.featured ? ' • مميز' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Palette.ivoryDim),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'تعديل',
                                  icon: const Icon(Icons.edit_outlined, color: Palette.gold),
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookFormPage(book: b))),
                                ),
                                IconButton(
                                  tooltip: 'حذف',
                                  icon: const Icon(Icons.delete_outline, color: Palette.danger),
                                  onPressed: () => _delete(b),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ============================================================ التصنيفات
class _CategoriesTab extends StatelessWidget {
  const _CategoriesTab();

  static const _palette = [
    0xFF8E3B46, 0xFF2E7D6B, 0xFF2F5D9E, 0xFF8A5A2B, 0xFFC26A2C, 0xFF4D3F8E,
    0xFF1F6F8B, 0xFF6B7A2E, 0xFFA33D6E, 0xFF3A6B35, 0xFF7B4B94, 0xFF9E6B2F,
  ];

  Future<void> _edit(BuildContext context, {Category? existing}) async {
    final catalog = context.read<CatalogState>();
    final name = TextEditingController(text: existing?.name ?? '');
    var slug = existing?.slug ?? 'book';
    var color = existing?.color ?? _palette.first;
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(existing == null ? 'تصنيف جديد' : 'تعديل التصنيف'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    autofocus: true,
                    validator: (v) => (v ?? '').trim().length < 2 ? 'أدخل اسم التصنيف' : null,
                    decoration: const InputDecoration(labelText: 'اسم التصنيف'),
                  ),
                  const SizedBox(height: 14),
                  const Align(alignment: AlignmentDirectional.centerStart, child: Text('الأيقونة', style: TextStyle(color: Palette.ivoryDim, fontSize: 12))),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: kCategoryIcons.entries
                        .map((e) => InkWell(
                              onTap: () => set(() => slug = e.key),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: slug == e.key ? Palette.gold : Palette.night,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: slug == e.key ? Palette.gold : Palette.line),
                                ),
                                child: Icon(e.value, size: 20, color: slug == e.key ? Palette.night : Palette.ivory),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                  const Align(alignment: AlignmentDirectional.centerStart, child: Text('اللون', style: TextStyle(color: Palette.ivoryDim, fontSize: 12))),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _palette
                        .map((c) => InkWell(
                              onTap: () => set(() => color = c),
                              customBorder: const CircleBorder(),
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Color(c),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: color == c ? Palette.gold : Colors.transparent, width: 3),
                                ),
                                child: color == c ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !context.mounted) return;
    if (existing == null) {
      await catalog.addCategory(name: name.text.trim(), slug: slug, color: color);
    } else {
      await catalog.updateCategory(Category(id: existing.id, name: name.text.trim(), slug: slug, color: color));
    }
    if (context.mounted) notify(context, existing == null ? 'تمت إضافة التصنيف' : 'تم تحديث التصنيف', icon: Icons.check_circle_outline);
  }

  Future<void> _delete(BuildContext context, Category c) async {
    final catalog = context.read<CatalogState>();
    final n = catalog.byCategory(c.id).length;
    if (n > 0) {
      notify(context, 'لا يمكن حذف "${c.name}" لأنه يحوي $n كتاب — انقل الكتب أو احذفها أولاً', error: true);
      return;
    }
    final ok = await confirm(context, title: 'حذف التصنيف', message: 'حذف "${c.name}" نهائياً؟', okLabel: 'حذف', destructive: true);
    if (!ok || !context.mounted) return;
    await catalog.deleteCategory(c.id);
    if (context.mounted) notify(context, 'تم حذف التصنيف', icon: Icons.delete_outline);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogState>();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'admin-add-cat',
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add),
        label: const Text('تصنيف جديد'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        itemCount: catalog.categories.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final c = catalog.categories[i];
          final n = catalog.byCategory(c.id).length;
          return Card(
            child: ListTile(
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: Color(c.color), borderRadius: BorderRadius.circular(10)),
                child: Icon(categoryIcon(c.slug), color: Colors.white),
              ),
              title: Text(c.name),
              subtitle: Text('$n كتاب', style: const TextStyle(color: Palette.ivoryDim, fontSize: 12)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.edit_outlined, color: Palette.gold), onPressed: () => _edit(context, existing: c)),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: n > 0 ? Palette.ivoryDim : Palette.danger),
                    onPressed: () => _delete(context, c),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================ الإحصاءات
class _StatsTab extends StatefulWidget {
  const _StatsTab();
  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> {
  int _users = 0, _orders = 0;
  double _revenue = 0;
  List<(Book, int)> _best = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = await UserRepo().countAll();
    final o = await OrderRepo().countAll();
    final r = await OrderRepo().revenue();
    final b = await CatalogRepo().bestSellers();
    if (!mounted) return;
    setState(() {
      _users = u;
      _orders = o;
      _revenue = r;
      _best = b;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogState>();
    if (_loading) return const Center(child: CircularProgressIndicator(color: Palette.gold));
    return RefreshIndicator(
      color: Palette.gold,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.6,
            children: [
              _Stat(icon: Icons.menu_book_outlined, label: 'الكتب', value: '${catalog.books.length}'),
              _Stat(icon: Icons.category_outlined, label: 'التصنيفات', value: '${catalog.categories.length}'),
              _Stat(icon: Icons.people_outline, label: 'المستخدمون', value: '$_users'),
              _Stat(icon: Icons.receipt_long_outlined, label: 'الطلبات', value: '$_orders'),
            ],
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.payments_outlined, color: Palette.gold, size: 30),
              title: const Text('إجمالي الإيرادات (محاكاة)'),
              trailing: Text(fmtPrice(_revenue), style: AppText.serifStyle(18, color: Palette.gold)),
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle(title: 'الأكثر مبيعاً'),
          const SizedBox(height: 6),
          if (_best.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('لا توجد مبيعات بعد', style: TextStyle(color: Palette.ivoryDim))),
            )
          else
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < _best.length; i++)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: i == 0 ? Palette.gold : Palette.night,
                        child: Text('${i + 1}', style: TextStyle(color: i == 0 ? Palette.night : Palette.ivory, fontWeight: FontWeight.w800)),
                      ),
                      title: Text(_best[i].$1.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(_best[i].$1.author, style: const TextStyle(fontSize: 12, color: Palette.ivoryDim)),
                      trailing: Text('${_best[i].$2} نسخة', style: const TextStyle(color: Palette.gold, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          const SectionTitle(title: 'الكتب حسب التصنيف'),
          const SizedBox(height: 6),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  for (final c in catalog.categories) ...[
                    Row(
                      children: [
                        Icon(categoryIcon(c.slug), size: 16, color: Color(c.color)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(c.name, style: const TextStyle(fontSize: 13))),
                        Text('${catalog.byCategory(c.id).length}', style: const TextStyle(color: Palette.gold, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: catalog.books.isEmpty ? 0 : catalog.byCategory(c.id).length / catalog.books.length,
                      color: Color(c.color),
                      backgroundColor: Palette.line,
                      minHeight: 5,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _Stat({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, color: Palette.gold, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: AppText.serifStyle(22, color: Palette.ivory)),
                Text(label, style: const TextStyle(color: Palette.ivoryDim, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
