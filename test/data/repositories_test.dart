import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sijil/core/ledger/ledger_models.dart';
import 'package:sijil/core/ledger/tx_type.dart';
import 'package:sijil/core/money/currency.dart';
import 'package:sijil/core/money/money.dart';
import 'package:sijil/data/models/customer.dart';
import 'package:sijil/data/repositories/customer_repository.dart';
import 'package:sijil/data/repositories/dashboard_repository.dart';
import 'package:sijil/data/repositories/transactions_repository.dart';
import 'package:sijil/data/session/session_provider.dart';

import '../ledger/test_helpers.dart';

Money y(int n) => Money(n, Currency.yer);

void main() {
  late TestEnv env;
  late CustomerRepository customers;
  late TransactionsRepository txs;

  setUp(() async {
    env = await TestEnv.create();
    customers = CustomerRepository(env.db, shopId: shopId, deviceId: deviceA);
    txs = TransactionsRepository(env.db);
  });
  tearDown(() => env.close());

  group('CustomerRepository', () {
    test('add trims name, cleans phone, writes audit', () async {
      final c = await customers.add(
          name: '  أحمد صالح ', phone: '77 1-234 567', byUserId: owner.userId);
      expect(c.name, 'أحمد صالح');
      expect(c.phone, '771234567');
      expect(c.phoneE164, '+967771234567');
      final audit = await env.db.query('audit_log', where: 'entity_id = ?', whereArgs: [c.id]);
      expect(audit.length, 1);
      expect(audit.first['action'], 'create');
    });

    test('empty name rejected', () async {
      expect(() => customers.add(name: '   ', byUserId: owner.userId), throwsArgumentError);
    });

    test('phoneE164 variants', () {
      Customer mk(String p) => Customer(
          id: 'x', shopId: shopId, name: 'n', phone: p, isArchived: false,
          createdAt: DateTime.utc(2026));
      expect(mk('+967771234567').phoneE164, '+967771234567');
      expect(mk('00967771234567').phoneE164, '+967771234567');
      expect(mk('967771234567').phoneE164, '+967771234567');
      expect(mk('0771234567').phoneE164, '+967771234567');
      expect(mk('771234567').phoneE164, '+967771234567');
    });

    test('list: balances, filters, sort by debt', () async {
      final a = await customers.add(name: 'أحمد', byUserId: owner.userId);
      final b = await customers.add(name: 'بدر', byUserId: owner.userId);
      final c = await customers.add(name: 'جميل', byUserId: owner.userId);
      await env.ledger.record(NewTransaction(customerId: a.id, type: TxType.debit, amount: y(5000)), owner);
      await env.ledger.record(NewTransaction(customerId: b.id, type: TxType.debit, amount: y(9000)), owner);
      await env.ledger.record(NewTransaction(customerId: b.id, type: TxType.credit, amount: y(1000)), owner);
      // c: settled (debit then equal credit)
      await env.ledger.record(NewTransaction(customerId: c.id, type: TxType.debit, amount: y(300)), owner);
      await env.ledger.record(NewTransaction(customerId: c.id, type: TxType.credit, amount: y(300)), owner);

      final all = await customers.list(sort: CustomerSort.largestDebt);
      expect(all.map((x) => x.customer.name).toList(), ['بدر', 'أحمد', 'جميل']);
      expect(all[0].primaryBalance, y(8000));
      expect(all[2].primaryBalance.isZero, isTrue);

      final owing = await customers.list(filter: CustomerFilter.owing);
      expect(owing.length, 2);
      final settled = await customers.list(filter: CustomerFilter.settled);
      expect(settled.single.customer.name, 'جميل');

      final alpha = await customers.list(sort: CustomerSort.alphabetical);
      expect(alpha.map((x) => x.customer.name).toList(), ['أحمد', 'بدر', 'جميل']);

      final q = await customers.list(query: 'بد');
      expect(q.single.customer.name, 'بدر');
    });

    test('overdue = owes and no credit in 30 days', () async {
      final a = await customers.add(name: 'أحمد', byUserId: owner.userId);
      final b = await customers.add(name: 'بدر', byUserId: owner.userId);
      final old = DateTime.now().toUtc().subtract(const Duration(days: 40));
      await env.ledger.record(
          NewTransaction(customerId: a.id, type: TxType.debit, amount: y(5000), occurredAt: old), owner);
      await env.ledger.record(
          NewTransaction(customerId: b.id, type: TxType.debit, amount: y(5000), occurredAt: old), owner);
      await env.ledger.record(
          NewTransaction(customerId: b.id, type: TxType.credit, amount: y(500),
              occurredAt: DateTime.now().toUtc().subtract(const Duration(days: 2))), owner);
      final overdue = await customers.list(filter: CustomerFilter.overdue);
      expect(overdue.single.customer.name, 'أحمد');
    });

    test('archive hides from list unless includeArchived', () async {
      final a = await customers.add(name: 'أحمد', byUserId: owner.userId);
      await customers.setArchived(a.id, true, byUserId: owner.userId);
      expect(await customers.list(), isEmpty);
      expect((await customers.list(includeArchived: true)).length, 1);
      expect((await customers.getById(a.id))!.isArchived, isTrue);
    });

    test('other-currency balances kept separate (R4)', () async {
      await env.activateCurrency('SAR');
      final a = await customers.add(name: 'أحمد', byUserId: owner.userId);
      await env.ledger.record(NewTransaction(customerId: a.id, type: TxType.debit, amount: y(1000)), owner);
      await env.ledger.record(
          NewTransaction(customerId: a.id, type: TxType.debit, amount: Money(5000, Currency.sar)), owner);
      final l = await customers.list();
      expect(l.single.primaryBalance, y(1000));
      expect(l.single.otherBalances[Currency.sar], Money(5000, Currency.sar));
    });
  });

  group('TransactionsRepository', () {
    test('paging, filters, customer scope, search', () async {
      final a = await customers.add(name: 'أحمد', byUserId: owner.userId);
      final b = await customers.add(name: 'بدر', byUserId: owner.userId);
      for (var i = 0; i < 25; i++) {
        env.clock.advance(const Duration(minutes: 1));
        await env.ledger.record(
            NewTransaction(customerId: i.isEven ? a.id : b.id,
                type: i % 5 == 0 ? TxType.credit : TxType.debit,
                amount: y(100 + i), noteText: i == 7 ? 'سكر' : null),
            owner);
      }
      final p1 = await txs.page(limit: 20);
      final p2 = await txs.page(limit: 20, offset: 20);
      expect(p1.length, 20);
      expect(p2.length, 5);
      // newest first
      expect(p1.first.tx.amount, y(124));
      expect(p1.first.customerName, 'أحمد');

      final paid = await txs.page(filter: TxFilter.paid, limit: 50);
      expect(paid.length, 5);
      expect(paid.every((t) => t.tx.type == TxType.credit), isTrue);

      final onlyB = await txs.page(customerId: b.id, limit: 50);
      expect(onlyB.length, 12);

      final search = await txs.page(query: 'سكر');
      expect(search.single.tx.amount, y(107));
    });
  });

  group('DashboardRepository', () {
    test('totals, today, overdue, recent excludes reversed pairs', () async {
      final dash = DashboardRepository(env.db, env.ledger);
      final a = await customers.add(name: 'أحمد', byUserId: owner.userId);
      final b = await customers.add(name: 'بدر', byUserId: owner.userId);
      final now = DateTime.now().toUtc();
      final t1 = await env.ledger.record(
          NewTransaction(customerId: a.id, type: TxType.debit, amount: y(3000), occurredAt: now), owner);
      await env.ledger.record(
          NewTransaction(customerId: a.id, type: TxType.credit, amount: y(500), occurredAt: now), owner);
      await env.ledger.record(
          NewTransaction(customerId: b.id, type: TxType.debit, amount: y(7000),
              occurredAt: now.subtract(const Duration(days: 45))), owner);
      final wrong = await env.ledger.record(
          NewTransaction(customerId: b.id, type: TxType.debit, amount: y(999), occurredAt: now), owner);
      await env.ledger.reverse(wrong.id, owner, reason: 'خطأ');

      final d = await dash.load();
      expect(d.primaryTotal, y(2500 + 7000));
      expect(d.todayTook, y(3000)); // reversed 999 excluded
      expect(d.todayPaid, y(500));
      expect(d.overdue.single.name, 'بدر');
      expect(d.recent.any((r) => r.tx.id == wrong.id), isFalse);
      expect(d.recent.any((r) => r.tx.isReversal), isFalse);
      expect(d.recent.any((r) => r.tx.id == t1.id), isTrue);
    });
  });

  group('SessionProvider', () {
    test('createShop → owner logged in; PIN verify; logout/login', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await env.db.delete('users');
      await env.db.delete('shops');
      final s = SessionProvider(env.db, prefs);
      await s.load();
      expect(s.hasShop, isFalse);
      final owner = await s.createShop(shopName: ' بقالة النور ', ownerName: 'محمد', pin: '1234');
      expect(s.hasShop, isTrue);
      expect(s.shop!.name, 'بقالة النور');
      expect(s.isLoggedIn, isTrue);
      expect(s.isOwner, isTrue);
      expect(s.actor.canReverse, isTrue);
      expect(await s.verifyPin(owner.id, '1234'), isTrue);
      expect(await s.verifyPin(owner.id, '0000'), isFalse);
      await s.logout();
      expect(s.isLoggedIn, isFalse);
      expect(() => s.actor, throwsStateError);
      // persisted user restored on reload
      await s.login(owner.id);
      final s2 = SessionProvider(env.db, prefs);
      await s2.load();
      expect(s2.user?.id, owner.id);
    });

    test('hash is salted and deterministic', () {
      final h1 = SessionProvider.hashPin('1234', 's1');
      final h2 = SessionProvider.hashPin('1234', 's1');
      final h3 = SessionProvider.hashPin('1234', 's2');
      expect(h1, h2);
      expect(h1, isNot(h3));
      expect(h1.length, 64);
    });
  });
}
