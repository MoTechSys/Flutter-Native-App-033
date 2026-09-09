// أدوات مشتركة للاختبارات: قاعدة بيانات في الذاكرة، تفضيلات وهمية، مضيف RTL
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kitabi/app_theme.dart';
import 'package:kitabi/data/db.dart';
import 'package:kitabi/state/session.dart';
import 'package:kitabi/state/store_state.dart';
import 'package:kitabi/ui/shell.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// يفتح قاعدة بيانات SQLite في الذاكرة (تُبذر بالكتب الحقيقية تلقائيًا)
Future<void> openTestDb() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  await KitabiDb.instance.close();
  KitabiDb.instance.pathOverride = inMemoryDatabasePath;
  await KitabiDb.instance.open();
}

Future<void> closeTestDb() => KitabiDb.instance.close();

void fakePrefs([Map<String, Object> init = const {}]) => SharedPreferences.setMockInitialValues(init);

/// مضيف بسيط بنفس إعدادات التطبيق (RTL + عربي + الثيم)
Widget host(Widget child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: buildKitabiTheme(),
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (_, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
  home: child,
);

/// يبني أي صفحة مع نفس مزوّدي الحالة
typedef PageHost = Widget Function(Widget page);

/// مضيف كامل بحالة المتجر ومستخدم مسجّل (يستخدم في اختبارات Shell)
Future<Widget> hostSignedIn({Widget? child}) async => (await signedInHost())(child ?? const Shell());

Future<PageHost> signedInHost() async {
  final session = Session();
  final err = await session.signUp(name: 'مختبر', email: 'tester@kitabi.app', password: 'Secret123', phone: '777000000', city: 'صنعاء');
  assert(err == null, 'signUp failed: $err');
  final catalog = CatalogState();
  await catalog.load();
  final cart = CartState();
  await cart.bind(session.uid);
  final fav = FavoritesState();
  await fav.bind(session.uid);
  return (page) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: session),
      ChangeNotifierProvider.value(value: catalog),
      ChangeNotifierProvider.value(value: cart),
      ChangeNotifierProvider.value(value: fav),
    ],
    child: host(page),
  );
}

/// خادم وهمي يحاكي GitHub Contents API ثم الملف الخام
http.Client fakeServer({bool? active, String code = 'KTB-2025', bool gone = false, bool offline = false}) =>
    MockClient((req) async {
      if (offline) throw http.ClientException('network down');
      if (gone) return http.Response('', 404);
      final body = jsonEncode({'active': active, 'code': code, 'message': 'msg'});
      if (req.url.host == 'api.github.com') {
        return http.Response(
          jsonEncode({'content': base64Encode(utf8.encode(body)), 'encoding': 'base64'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response(body, 200);
    });

/// حجم هاتف شائع (360×780 منطقي)
Future<void> phoneSize(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360 * 3, 780 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}
