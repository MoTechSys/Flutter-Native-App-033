import 'package:sqflite_common/sqlite_api.dart';
import 'package:uuid/uuid.dart';

import '../../core/ledger/ledger_models.dart';
import '../../core/ledger/ledger_service.dart';
import '../../core/ledger/tx_type.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';

/// Seeds a realistic demo shop so the UI can be previewed before the
/// onboarding / customer screens exist (Phase 0 only). Idempotent.
class DemoSeed {
  static const shopId = 'demo-shop';
  static const ownerId = 'demo-owner';
  static const workerId = 'demo-worker';

  static Future<void> run(Database db, LedgerService ledger) async {
    final existing = await db.query('shops', where: 'id=?', whereArgs: [shopId]);
    if (existing.isNotEmpty) return;

    final now = DateTime.now().toUtc();
    final ms = now.millisecondsSinceEpoch;
    const uuid = Uuid();

    await db.insert('shops', {
      'id': shopId,
      'name': 'بقالة الأمل',
      'address': 'صنعاء - شارع الستين',
      'phone': '777123456',
      'created_at': ms,
    });
    await db.insert('users', {
      'id': ownerId, 'shop_id': shopId, 'name': 'صالح أحمد', 'role': 'owner', 'created_at': ms,
    });
    await db.insert('users', {
      'id': workerId, 'shop_id': shopId, 'name': 'علي', 'role': 'worker', 'created_at': ms,
    });

    final names = [
      'أحمد صالح', 'محمد علي', 'علي حسن', 'صالح ناصر', 'عبدالله محسن',
      'حسين عبده', 'فهد سعيد', 'أم محمد', 'يحيى قاسم', 'نبيل عوض',
    ];
    final ids = <String>[];
    for (var i = 0; i < names.length; i++) {
      final id = uuid.v4();
      ids.add(id);
      await db.insert('customers', {
        'id': id, 'shop_id': shopId, 'name': names[i],
        'phone': '77${(1000000 + i * 137).toString().padLeft(7, '0')}',
        'is_archived': 0, 'created_at': ms - i * 86400000, 'updated_at': ms,
      });
    }

    const owner = Actor.owner(ownerId, 'صالح أحمد');
    const worker = Actor.worker(workerId, 'علي');
    Money y(int n) => Money(n, Currency.yer);

    // Spread transactions over the last 45 days.
    final plan = <(int cust, TxType t, int amt, int daysAgo)>[
      (0, TxType.opening, 7000, 45), (0, TxType.debit, 2500, 30), (0, TxType.credit, 4000, 20),
      (0, TxType.debit, 3000, 3), (0, TxType.debit, 1500, 0),
      (1, TxType.debit, 12000, 40), (1, TxType.credit, 4000, 25),
      (2, TxType.debit, 5500, 38), (2, TxType.debit, 2500, 10), (2, TxType.credit, 8000, 1),
      (3, TxType.debit, 9000, 35), (3, TxType.credit, 2000, 2),
      (4, TxType.debit, 3200, 12), (4, TxType.credit, 1200, 0),
      (5, TxType.debit, 18000, 60), (5, TxType.credit, 3000, 33),
      (6, TxType.debit, 800, 1),
      (7, TxType.debit, 4500, 5), (7, TxType.credit, 2000, 0),
      (8, TxType.debit, 6000, 70),
      (9, TxType.debit, 2200, 0),
    ];
    for (final p in plan) {
      final at = now.subtract(Duration(days: p.$4, hours: (p.$3 % 7) + 1));
      final actor = p.$2.ownerOnly ? owner : worker;
      await ledger.record(
        NewTransaction(customerId: ids[p.$1], type: p.$2, amount: y(p.$3), occurredAt: at),
        actor,
      );
    }
    await ledger.rebuildCache();
  }
}
