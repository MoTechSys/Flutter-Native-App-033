// ============================================================
// كِتابي - متجر كتب (محاكاة)
// تصفح حسب التصنيفات، بحث، سلة مشتريات، مفضلة، تفاصيل ومراجعات
//
// إعداد الطالب: علي عبده يحيى
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'data/db.dart';
import 'security/access_control.dart';
import 'state/session.dart';
import 'state/store_state.dart';
import 'ui/auth/sign_in_page.dart';
import 'ui/lock/locked_page.dart';
import 'ui/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await KitabiDb.instance.open();
  runApp(const KitabiApp());
}

class KitabiApp extends StatelessWidget {
  const KitabiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Session()),
        ChangeNotifierProvider(create: (_) => CatalogState()),
        ChangeNotifierProvider(create: (_) => CartState()),
        ChangeNotifierProvider(create: (_) => FavoritesState()),
      ],
      child: MaterialApp(
        title: 'كِتابي',
        debugShowCheckedModeBanner: false,
        theme: buildKitabiTheme(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        home: const _Gate(),
      ),
    );
  }
}

/// البوابة: ترخيص -> جلسة -> الهيكل
class _Gate extends StatefulWidget {
  const _Gate();
  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  AccessDecision? _decision;
  bool _ready = false;
  int? _boundUid;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final decision = await AccessControl.resolve();
    if (!mounted) return;
    await context.read<Session>().restore();
    if (!mounted) return;
    await context.read<CatalogState>().load();
    if (!mounted) return;
    setState(() {
      _decision = decision;
      _ready = true;
    });
  }

  /// ربط السلة والمفضلة بالمستخدم الحالي عند تغيّر الجلسة
  void _bind(Session s) {
    final uid = s.signedIn ? s.uid : 0;
    if (uid == _boundUid) return;
    _boundUid = uid;
    final cart = context.read<CartState>();
    final fav = context.read<FavoritesState>();
    if (uid == 0) {
      cart.unbind();
      fav.unbind();
    } else {
      cart.bind(uid);
      fav.bind(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const _Splash();
    if (!_decision!.allowed) {
      return LockedPage(
        decision: _decision!,
        onGranted: () => setState(() => _decision = const Granted()),
      );
    }
    final session = context.watch<Session>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bind(session));
    if (!session.signedIn) return const SignInPage();
    return const Shell();
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Palette.gold, Palette.goldDim]),
            ),
            child: const Icon(Icons.menu_book_rounded, size: 42, color: Palette.night),
          ),
          const SizedBox(height: 16),
          Text('كِتابي', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Palette.gold, fontSize: 30)),
          const SizedBox(height: 26),
          const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5, color: Palette.gold)),
        ],
      ),
    ),
  );
}
