import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'app.dart';
import 'core/db/app_database.dart';
import 'core/db/db_factory.dart';
import 'core/ledger/ledger_service.dart';
import 'data/app_services.dart';
import 'data/demo/demo_seed.dart';
import 'data/session/session_provider.dart';

/// `flutter build web --dart-define=DEMO=true` seeds the demo shop for preview.
/// Release builds start empty and go through onboarding (docs/10 audit gap #1).
const bool kDemo = bool.fromEnvironment('DEMO', defaultValue: false);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Stable per-install device id (R5/R6 — needed for multi-device sync).
  final prefs = await SharedPreferences.getInstance();
  var deviceId = prefs.getString('device_id');
  if (deviceId == null) {
    deviceId = const Uuid().v4();
    await prefs.setString('device_id', deviceId);
  }

  final (factory, path) = await resolveDatabaseFactory('sijil.db');
  final adb = await AppDatabase.open(factory: factory, path: path);

  if (kDemo) {
    final ledger = LedgerService(db: adb.db, shopId: DemoSeed.shopId, deviceId: deviceId);
    await DemoSeed.run(adb.db, ledger);
    await ledger.rebuildCache();
  }

  final session = SessionProvider(adb.db, prefs);
  await session.load();
  if (kDemo && !session.isLoggedIn && session.users.isNotEmpty) {
    await session.login(session.users.first.id); // demo owner
  }

  final services = AppServices(db: adb.db, deviceId: deviceId, session: session);

  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: adb),
        ChangeNotifierProvider<SessionProvider>.value(value: session),
        ChangeNotifierProvider<AppServices>.value(value: services),
      ],
      child: const SijilApp(),
    ),
  );
}
