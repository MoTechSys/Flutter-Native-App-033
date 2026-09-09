// ============================================================
// كِتابي - الهيكل الرئيسي: 4 تبويبات، كلٌّ منها بـ Navigator مستقل
//
// سلوك زر الرجوع (مهم):
//   - داخل تبويب وفيه صفحات مفتوحة  -> يرجع صفحة واحدة (بنفس ترتيب الدخول)
//   - تبويب غير الرئيسية بلا صفحات   -> ينتقل إلى تبويب الرئيسية
//   - الرئيسية بلا صفحات            -> يطلب تأكيد الخروج (لا يخرج فجأة)
// المرجع: PopScope (Flutter 3.16+) بدل WillPopScope المهجور؛ canPop:false + معالجة يدوية للتنقل المتداخل.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../state/store_state.dart';
import 'cart/cart_page.dart';
import 'favorites/favorites_page.dart';
import 'home/categories_page.dart';
import 'home/home_page.dart';

enum ShellTab { home, categories, cart, favorites }

/// للوصول إلى الهيكل من أي صفحة داخلية (مثلاً: "اذهب إلى السلة")
class ShellController extends ChangeNotifier {
  int _index = 0;
  int get index => _index;
  void go(ShellTab t) {
    if (_index == t.index) return;
    _index = t.index;
    notifyListeners();
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  final _controller = ShellController();
  final _keys = List.generate(ShellTab.values.length, (_) => GlobalKey<NavigatorState>());

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  NavigatorState get _current => _keys[_controller.index].currentState!;

  Future<void> _onBack() async {
    // 1) صفحة مفتوحة داخل التبويب الحالي؟ ارجع خطوة
    if (_current.canPop()) {
      _current.pop();
      return;
    }
    // 2) لست في الرئيسية؟ اذهب إليها
    if (_controller.index != ShellTab.home.index) {
      _controller.go(ShellTab.home);
      return;
    }
    // 3) في الرئيسية: تأكيد الخروج
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('الخروج من كِتابي؟'),
        content: const Text('هل تريد إغلاق التطبيق؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('البقاء')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('خروج', style: TextStyle(color: Palette.danger)),
          ),
        ],
      ),
    );
    if (leave == true) SystemNavigator.pop();
  }

  void _select(int i) {
    if (i == _controller.index) {
      // نقرة على التبويب الحالي = ارجع إلى جذره
      _current.popUntil((r) => r.isFirst);
    } else {
      _controller.go(ShellTab.values[i]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartState>().count;
    final favCount = context.watch<FavoritesState>().count;

    return ChangeNotifierProvider.value(
      value: _controller,
      // PopScope(canPop:false) يعترض زر الرجوع دائماً ويحوّله إلى _onBack()
      // (NavigatorPopHandler يترك النظام يخرج من التطبيق عند جذر التبويب — وهذا غير مرغوب)
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _onBack();
        },
        child: Scaffold(
          body: IndexedStack(
            index: _controller.index,
            children: [
              _TabNavigator(navKey: _keys[0], root: const HomePage()),
              _TabNavigator(navKey: _keys[1], root: const CategoriesPage()),
              _TabNavigator(navKey: _keys[2], root: const CartPage()),
              _TabNavigator(navKey: _keys[3], root: const FavoritesPage()),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _controller.index,
            onDestinationSelected: _select,
            height: 68,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'الرئيسية',
              ),
              const NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view_rounded),
                label: 'التصنيفات',
              ),
              NavigationDestination(
                icon: _Badged(count: cartCount, child: const Icon(Icons.shopping_bag_outlined)),
                selectedIcon: _Badged(count: cartCount, child: const Icon(Icons.shopping_bag_rounded)),
                label: 'السلة',
              ),
              NavigationDestination(
                icon: _Badged(count: favCount, child: const Icon(Icons.favorite_outline)),
                selectedIcon: _Badged(count: favCount, child: const Icon(Icons.favorite_rounded)),
                label: 'المفضلة',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabNavigator extends StatelessWidget {
  final GlobalKey<NavigatorState> navKey;
  final Widget root;
  const _TabNavigator({required this.navKey, required this.root});

  @override
  Widget build(BuildContext context) => Navigator(
    key: navKey,
    onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => root),
  );
}

class _Badged extends StatelessWidget {
  final int count;
  final Widget child;
  const _Badged({required this.count, required this.child});
  @override
  Widget build(BuildContext context) => Badge.count(
    count: count,
    isLabelVisible: count > 0,
    backgroundColor: Palette.gold,
    textColor: Palette.night,
    child: child,
  );
}
