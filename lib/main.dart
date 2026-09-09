import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'app.dart';
import 'core/db/app_database.dart';
import 'core/db/db_factory.dart';
import 'core/ledger/ledger_service.dart';
import 'data/demo/demo_seed.dart';
import 'data/repositories/dashboard_repository.dart';

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

  final ledger = LedgerService(db: adb.db, shopId: DemoSeed.shopId, deviceId: deviceId);

  // Phase 0: demo data so the dashboard has something to show.
  await DemoSeed.run(adb.db, ledger);
  await ledger.rebuildCache();

  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: adb),
        Provider<LedgerService>.value(value: ledger),
        Provider<DashboardRepository>(create: (_) => DashboardRepository(adb.db, ledger)),
      ],
      child: const SijilApp(),
    ),
  );
}
