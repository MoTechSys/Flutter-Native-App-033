// ============================================================
// كِتابي - التصنيفات (شبكة 2×3 تملأ الشاشة بلا تمرير)
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../state/store_state.dart';
import 'book_list_page.dart';
import 'home_page.dart' show categoryIcon;

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogState>();
    final cats = catalog.categories;
    return Scaffold(
      appBar: AppBar(
        title: const Text('التصنيفات'),
        actions: [
          IconButton(
            tooltip: 'بحث',
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BookListPage(title: 'بحث', autofocusSearch: true)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            children: [
              Text(
                '${catalog.books.length} كتاباً في ${cats.length} تصنيفات',
                style: const TextStyle(color: Palette.ivoryDim, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.05,
                  ),
                  itemCount: cats.length,
                  itemBuilder: (_, i) {
                    final c = cats[i];
                    final color = Color(c.color);
                    final count = catalog.byCategory(c.id).length;
                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => BookListPage(title: c.name, categoryId: c.id)),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                            colors: [color.withValues(alpha: 0.55), Palette.nightSoft],
                          ),
                          border: Border.all(color: color.withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
                              child: Icon(categoryIcon(c.slug), color: Palette.ivory, size: 24),
                            ),
                            const Spacer(),
                            Text(c.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontFamily: AppText.serif, fontSize: 17)),
                            Text('$count كتب', style: const TextStyle(color: Palette.ivoryDim, fontSize: 12)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
