// ============================================================
// كِتابي - المفضلة (شبكة) + إضافة الكل إلى السلة
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/store_state.dart';
import '../home/book_list_page.dart' show BookGridCard;
import '../shared/widgets.dart';
import '../shell.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final fav = context.watch<FavoritesState>();
    final books = fav.books;
    return Scaffold(
      appBar: AppBar(
        title: Text('المفضلة${books.isEmpty ? '' : ' (${books.length})'}'),
        actions: [
          if (books.isNotEmpty)
            IconButton(
              tooltip: 'مسح المفضلة',
              icon: const Icon(Icons.heart_broken_outlined),
              onPressed: () async {
                if (await confirm(context, title: 'مسح المفضلة', message: 'إزالة جميع الكتب من المفضلة؟', okLabel: 'مسح', destructive: true)) {
                  await fav.clear();
                  if (context.mounted) notify(context, 'تم مسح المفضلة');
                }
              },
            ),
        ],
      ),
      body: SafeArea(
        child: books.isEmpty
            ? EmptyView(
                icon: Icons.favorite_border,
                title: 'لا توجد كتب مفضلة',
                subtitle: 'اضغط على ♥ في أي كتاب لحفظه هنا',
                action: OutlinedButton.icon(
                  onPressed: () => context.read<ShellController>().go(ShellTab.categories),
                  icon: const Icon(Icons.grid_view_outlined),
                  label: const Text('استعرض التصنيفات'),
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.56,
                      ),
                      itemCount: books.length,
                      itemBuilder: (_, i) => BookGridCard(book: books[i]),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: FilledButton.icon(
                      onPressed: () async {
                        final cart = context.read<CartState>();
                        for (final b in books) {
                          if (!cart.contains(b.id)) await cart.add(b);
                        }
                        if (context.mounted) notify(context, 'أُضيفت المفضلة إلى السلة', icon: Icons.shopping_bag);
                      },
                      icon: const Icon(Icons.add_shopping_cart),
                      label: Text('أضف الكل إلى السلة (${books.length})'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
