import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sijil/core/db/app_database.dart';
import 'package:sijil/core/ledger/ledger_models.dart';
import 'package:sijil/core/ledger/ledger_service.dart';

const shopId = 'shop-1';
const deviceA = 'device-A';
const deviceB = 'device-B';
const owner = Actor.owner('u-owner', 'أبو أحمد');
const worker = Actor.worker('u-worker', 'صالح');

/// Fixed, controllable clock.
class FakeClock {
  DateTime now = DateTime.utc(2026, 9, 9, 10, 0, 0);
  DateTime call() => now;
  void advance(Duration d) => now = now.add(d);
}

class TestEnv {
  final AppDatabase adb;
  final Database db;
  final FakeClock clock;
  final LedgerService ledger;
  TestEnv(this.adb, this.db, this.clock, this.ledger);

  static Future<TestEnv> create({String deviceId = deviceA}) async {
    sqfliteFfiInit();
    final adb = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    final clock = FakeClock();
    await adb.db.insert('shops', {
      'id': shopId,
      'name': 'بقالة الأمل',
      'created_at': clock.now.millisecondsSinceEpoch,
    });
    await adb.db.insert('users', {
      'id': owner.userId, 'shop_id': shopId, 'name': owner.name,
      'role': 'owner', 'created_at': clock.now.millisecondsSinceEpoch,
    });
    await adb.db.insert('users', {
      'id': worker.userId, 'shop_id': shopId, 'name': worker.name,
      'role': 'worker', 'created_at': clock.now.millisecondsSinceEpoch,
    });
    final ledger = LedgerService(
      db: adb.db, shopId: shopId, deviceId: deviceId, clock: clock.call);
    return TestEnv(adb, adb.db, clock, ledger);
  }

  Future<String> addCustomer(String name,
      {String? id, int? creditLimit, String? creditCurrency, bool archived = false}) async {
    final cid = id ?? 'c-$name';
    await db.insert('customers', {
      'id': cid, 'shop_id': shopId, 'name': name,
      'credit_limit_minor': creditLimit,
      'credit_limit_currency': creditCurrency,
      'is_archived': archived ? 1 : 0,
      'created_at': clock.now.millisecondsSinceEpoch,
      'updated_at': clock.now.millisecondsSinceEpoch,
    });
    return cid;
  }

  Future<void> activateCurrency(String code) =>
      db.update('currencies', {'is_active': 1}, where: 'code = ?', whereArgs: [code]);

  Future<void> lockBefore(DateTime d) => db.insert(
        'settings',
        {'key': 'locked_before', 'value_json': jsonEncode(d.millisecondsSinceEpoch)},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<void> close() => adb.close();
}
