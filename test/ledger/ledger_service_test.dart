import 'package:flutter_test/flutter_test.dart';
import 'package:sijil/core/ledger/ledger_errors.dart';
import 'package:sijil/core/ledger/ledger_models.dart';
import 'package:sijil/core/ledger/tx_type.dart';
import 'package:sijil/core/money/currency.dart';
import 'package:sijil/core/money/money.dart';

import 'test_helpers.dart';

Money yer(int n) => Money(n, Currency.yer);
Money sar(int n) => Money(n, Currency.sar);

void main() {
  late TestEnv env;
  late String ahmed;

  setUp(() async {
    env = await TestEnv.create();
    ahmed = await env.addCustomer('أحمد صالح');
  });
  tearDown(() => env.close());

  NewTransaction debit(int n, {String? cid, DateTime? at}) => NewTransaction(
      customerId: cid ?? ahmed, type: TxType.debit, amount: yer(n), occurredAt: at);
  NewTransaction credit(int n, {String? cid, DateTime? at}) => NewTransaction(
      customerId: cid ?? ahmed, type: TxType.credit, amount: yer(n), occurredAt: at);

  group('recording basics', () {
    test('debit increases balance, credit decreases', () async {
      await env.ledger.record(debit(5000), worker);
      var b = await env.ledger.balance(ahmed, Currency.yer);
      expect(b.balance.minor, 5000);
      expect(b.owes, true);

      await env.ledger.record(credit(2000), worker);
      b = await env.ledger.balance(ahmed, Currency.yer);
      expect(b.balance.minor, 3000);
      expect(b.txCount, 2);
    });

    test('snapshots stored (R8)', () async {
      final tx = await env.ledger.record(debit(100), worker);
      expect(tx.customerNameSnap, 'أحمد صالح');
      expect(tx.userNameSnap, 'صالح');
      expect(tx.recordedBy, worker.userId);
    });

    test('recorded_at is clock time, occurred_at defaults to now (R7)', () async {
      final tx = await env.ledger.record(debit(100), worker);
      expect(tx.recordedAt, env.clock.now);
      expect(tx.occurredAt, env.clock.now);
    });

    test('occurred_at can be backdated', () async {
      final past = env.clock.now.subtract(const Duration(days: 3));
      final tx = await env.ledger.record(debit(100, at: past), worker);
      expect(tx.occurredAt, past);
      expect(tx.recordedAt, env.clock.now);
    });

    test('local_seq increments per device (R6)', () async {
      final a = await env.ledger.record(debit(1), worker);
      final b = await env.ledger.record(debit(1), worker);
      expect(a.localSeq, 1);
      expect(b.localSeq, 2);
      expect(a.deviceId, deviceA);
    });

    test('ids are UUIDs and unique (R5)', () async {
      final a = await env.ledger.record(debit(1), worker);
      final b = await env.ledger.record(debit(1), worker);
      expect(a.id, isNot(b.id));
      expect(a.id.length, 36);
    });

    test('updates customer.last_activity_at', () async {
      await env.ledger.record(debit(1), worker);
      final r = await env.db.query('customers', where: 'id=?', whereArgs: [ahmed]);
      expect(r.first['last_activity_at'], env.clock.now.millisecondsSinceEpoch);
    });

    test('writes audit_log', () async {
      await env.ledger.record(debit(1), worker);
      final r = await env.db.query('audit_log');
      expect(r.length, 1);
      expect(r.first['action'], 'record');
      expect(r.first['actor_id'], worker.userId);
    });
  });

  group('validation (edges #2,#3,#4,#10)', () {
    test('zero amount rejected', () async {
      expect(() => env.ledger.record(debit(0), worker), throwsA(isA<InvalidAmountError>()));
    });
    test('negative amount rejected', () async {
      expect(() => env.ledger.record(debit(-5), worker), throwsA(isA<InvalidAmountError>()));
    });
    test('inactive currency rejected', () async {
      final tx = NewTransaction(customerId: ahmed, type: TxType.debit, amount: sar(100));
      expect(() => env.ledger.record(tx, worker), throwsA(isA<InactiveCurrencyError>()));
    });
    test('active currency accepted', () async {
      await env.activateCurrency('SAR');
      final tx = NewTransaction(customerId: ahmed, type: TxType.debit, amount: sar(100));
      final saved = await env.ledger.record(tx, worker);
      expect(saved.amount.currency, Currency.sar);
    });
    test('future date rejected beyond tolerance', () async {
      final fut = env.clock.now.add(const Duration(minutes: 6));
      expect(() => env.ledger.record(debit(1, at: fut), worker), throwsA(isA<FutureDateError>()));
    });
    test('future date within tolerance accepted', () async {
      final fut = env.clock.now.add(const Duration(minutes: 4));
      final tx = await env.ledger.record(debit(1, at: fut), worker);
      expect(tx.occurredAt, fut);
    });
    test('unknown customer rejected', () async {
      expect(() => env.ledger.record(debit(1, cid: 'nope'), worker),
          throwsA(isA<CustomerNotFoundError>()));
    });
    test('DB CHECK also guards amount (defense in depth)', () async {
      expect(
        () => env.db.insert('transactions', {
          'id': 'x', 'shop_id': shopId, 'customer_id': ahmed, 'type': 'debit',
          'amount_minor': 0, 'currency_code': 'YER', 'occurred_at': 1, 'recorded_at': 1,
          'recorded_by': 'u', 'customer_name_snap': 'a', 'user_name_snap': 'b',
          'device_id': 'd', 'local_seq': 99,
        }),
        throwsA(anything),
      );
    });
  });

  group('R1 immutability (DB triggers)', () {
    test('DELETE is refused', () async {
      final tx = await env.ledger.record(debit(1), worker);
      expect(() => env.db.delete('transactions', where: 'id=?', whereArgs: [tx.id]),
          throwsA(anything));
      expect(await env.ledger.getById(tx.id), isNotNull);
    });
    test('UPDATE of amount is refused', () async {
      final tx = await env.ledger.record(debit(1), worker);
      expect(
        () => env.db.update('transactions', {'amount_minor': 999}, where: 'id=?', whereArgs: [tx.id]),
        throwsA(anything),
      );
      expect((await env.ledger.getById(tx.id))!.amount.minor, 1);
    });
    test('UPDATE of type is refused', () async {
      final tx = await env.ledger.record(debit(1), worker);
      expect(
        () => env.db.update('transactions', {'type': 'credit'}, where: 'id=?', whereArgs: [tx.id]),
        throwsA(anything),
      );
    });
    test('UPDATE of occurred_at is refused', () async {
      final tx = await env.ledger.record(debit(1), worker);
      expect(
        () => env.db.update('transactions', {'occurred_at': 5}, where: 'id=?', whereArgs: [tx.id]),
        throwsA(anything),
      );
    });
    test('setting reversed_by_id twice is refused', () async {
      final tx = await env.ledger.record(debit(1), worker);
      await env.ledger.reverse(tx.id, owner, reason: 'خطأ');
      expect(
        () => env.db.update('transactions', {'reversed_by_id': 'other'}, where: 'id=?', whereArgs: [tx.id]),
        throwsA(anything),
      );
    });
  });

  group('reversal (R1, R9, edges #6,#7,#8)', () {
    test('reverse restores balance and links both rows', () async {
      final tx = await env.ledger.record(debit(5000), worker);
      final rev = await env.ledger.reverse(tx.id, owner, reason: 'الزبون ما أخذ');
      final b = await env.ledger.balance(ahmed, Currency.yer);
      expect(b.balance.minor, 0);
      expect(b.txCount, 0, reason: 'reversed pair excluded from live count');
      expect(rev.type, TxType.credit);
      expect(rev.reversesId, tx.id);
      expect(rev.reversalReason, 'الزبون ما أخذ');
      expect((await env.ledger.getById(tx.id))!.reversedById, rev.id);
    });
    test('worker cannot reverse', () async {
      final tx = await env.ledger.record(debit(1), worker);
      expect(() => env.ledger.reverse(tx.id, worker, reason: 'x'), throwsA(isA<PermissionError>()));
    });
    test('reason required', () async {
      final tx = await env.ledger.record(debit(1), worker);
      expect(() => env.ledger.reverse(tx.id, owner, reason: '   '), throwsA(isA<ReasonRequiredError>()));
    });
    test('cannot reverse twice', () async {
      final tx = await env.ledger.record(debit(1), worker);
      await env.ledger.reverse(tx.id, owner, reason: 'a');
      expect(() => env.ledger.reverse(tx.id, owner, reason: 'b'), throwsA(isA<AlreadyReversedError>()));
    });
    test('cannot reverse a reversal', () async {
      final tx = await env.ledger.record(debit(1), worker);
      final rev = await env.ledger.reverse(tx.id, owner, reason: 'a');
      expect(() => env.ledger.reverse(rev.id, owner, reason: 'b'),
          throwsA(isA<CannotReverseReversalError>()));
    });
    test('unknown tx', () async {
      expect(() => env.ledger.reverse('nope', owner, reason: 'a'), throwsA(isA<TransactionNotFoundError>()));
    });
    test('reverse of credit is debit; of adjust_down is adjust_up', () async {
      final c = await env.ledger.record(credit(100), worker);
      final rc = await env.ledger.reverse(c.id, owner, reason: 'r');
      expect(rc.type, TxType.debit);
      final a = await env.ledger.record(
          NewTransaction(customerId: ahmed, type: TxType.adjustDown, amount: yer(50)), owner);
      final ra = await env.ledger.reverse(a.id, owner, reason: 'r');
      expect(ra.type, TxType.adjustUp);
      expect((await env.ledger.balance(ahmed, Currency.yer)).balance.minor, 0);
    });
  });

  group('permissions & types (R9, edge #12)', () {
    test('worker cannot record adjustments or opening', () async {
      for (final t in [TxType.adjustDown, TxType.adjustUp, TxType.opening]) {
        expect(
          () => env.ledger.record(NewTransaction(customerId: ahmed, type: t, amount: yer(1)), worker),
          throwsA(isA<PermissionError>()),
          reason: t.name,
        );
      }
    });
    test('owner records opening once per customer+currency', () async {
      await env.ledger.record(
          NewTransaction(customerId: ahmed, type: TxType.opening, amount: yer(7000)), owner);
      expect((await env.ledger.balance(ahmed, Currency.yer)).balance.minor, 7000);
      expect(
        () => env.ledger.record(
            NewTransaction(customerId: ahmed, type: TxType.opening, amount: yer(1)), owner),
        throwsA(isA<OpeningAlreadyExistsError>()),
      );
    });
    test('opening allowed again after its reversal', () async {
      final o = await env.ledger.record(
          NewTransaction(customerId: ahmed, type: TxType.opening, amount: yer(7000)), owner);
      await env.ledger.reverse(o.id, owner, reason: 'غلط');
      final o2 = await env.ledger.record(
          NewTransaction(customerId: ahmed, type: TxType.opening, amount: yer(6500)), owner);
      expect(o2.type, TxType.opening);
      expect((await env.ledger.balance(ahmed, Currency.yer)).balance.minor, 6500);
    });
    test('opening in a second currency is allowed', () async {
      await env.activateCurrency('SAR');
      await env.ledger.record(
          NewTransaction(customerId: ahmed, type: TxType.opening, amount: yer(100)), owner);
      await env.ledger.record(
          NewTransaction(customerId: ahmed, type: TxType.opening, amount: sar(100)), owner);
      final all = await env.ledger.balancesAllCurrencies(ahmed);
      expect(all.length, 2);
    });
  });

  group('multi-currency (R4)', () {
    test('balances kept separate per currency', () async {
      await env.activateCurrency('SAR');
      await env.ledger.record(debit(50000), worker);
      await env.ledger.record(
          NewTransaction(customerId: ahmed, type: TxType.debit, amount: sar(10000)), worker);
      expect((await env.ledger.balance(ahmed, Currency.yer)).balance.minor, 50000);
      expect((await env.ledger.balance(ahmed, Currency.sar)).balance.minor, 10000);
      final totals = await env.ledger.totalOwedByCurrency();
      expect(totals[Currency.yer]!.minor, 50000);
      expect(totals[Currency.sar]!.minor, 10000);
    });
    test('totalOwed ignores customers in credit (negative)', () async {
      final b = await env.addCustomer('بدر');
      await env.ledger.record(debit(1000), worker);
      await env.ledger.record(credit(3000, cid: b), worker); // بدر paid in advance → -3000
      final totals = await env.ledger.totalOwedByCurrency();
      expect(totals[Currency.yer]!.minor, 1000);
    });
  });

  group('edge #5 overpayment allowed', () {
    test('credit larger than balance → negative balance (customer in credit)', () async {
      await env.ledger.record(debit(1000), worker);
      await env.ledger.record(credit(1500), worker);
      final b = await env.ledger.balance(ahmed, Currency.yer);
      expect(b.balance.minor, -500);
      expect(b.inCredit, true);
      expect(b.owes, false);
    });
  });

  group('edge #13 archived customer', () {
    test('archived: debit refused, credit allowed', () async {
      final z = await env.addCustomer('زيد', archived: true);
      expect(() => env.ledger.record(debit(1, cid: z), worker), throwsA(isA<CustomerArchivedError>()));
      final c = await env.ledger.record(credit(1, cid: z), worker);
      expect(c.type, TxType.credit);
    });
  });

  group('edge #14 credit limit', () {
    test('exceeding limit is allowed but flagged', () async {
      final k = await env.addCustomer('كمال', creditLimit: 10000, creditCurrency: 'YER');
      final t1 = await env.ledger.record(debit(6000, cid: k), worker);
      expect(t1.overLimit, false);
      final t2 = await env.ledger.record(debit(6000, cid: k), worker);
      expect(t2.overLimit, true);
      expect((await env.ledger.balance(k, Currency.yer)).balance.minor, 12000);
    });
    test('limit in another currency does not flag', () async {
      final k = await env.addCustomer('كمال', creditLimit: 1, creditCurrency: 'SAR');
      final t = await env.ledger.record(debit(999999, cid: k), worker);
      expect(t.overLimit, false);
    });
  });

  group('edge #11 locked period (R7)', () {
    test('worker cannot backdate into locked period', () async {
      await env.lockBefore(env.clock.now.subtract(const Duration(days: 1)));
      final old = env.clock.now.subtract(const Duration(days: 10));
      expect(() => env.ledger.record(debit(1, at: old), worker), throwsA(isA<LockedPeriodError>()));
    });
    test('owner without reason is refused', () async {
      await env.lockBefore(env.clock.now.subtract(const Duration(days: 1)));
      final old = env.clock.now.subtract(const Duration(days: 10));
      expect(() => env.ledger.record(debit(1, at: old), owner), throwsA(isA<LockedPeriodError>()));
    });
    test('owner with reason is accepted and flagged', () async {
      await env.lockBefore(env.clock.now.subtract(const Duration(days: 1)));
      final old = env.clock.now.subtract(const Duration(days: 10));
      final tx = await env.ledger.record(
        NewTransaction(customerId: ahmed, type: TxType.debit, amount: yer(1), occurredAt: old, lockedReason: 'نسيان'),
        owner,
      );
      expect(tx.inLockedPeriod, true);
    });
    test('today is not locked', () async {
      await env.lockBefore(env.clock.now.subtract(const Duration(days: 1)));
      final tx = await env.ledger.record(debit(1), worker);
      expect(tx.inLockedPeriod, false);
    });
  });

  group('R6 idempotent import', () {
    test('same (device, seq) imported twice → inserted once, balance unchanged', () async {
      final row = {
        'id': 'imp-1', 'shop_id': shopId, 'customer_id': ahmed, 'type': 'debit',
        'amount_minor': 700, 'currency_code': 'YER',
        'occurred_at': env.clock.now.millisecondsSinceEpoch,
        'recorded_at': env.clock.now.millisecondsSinceEpoch,
        'recorded_by': 'u-remote', 'customer_name_snap': 'أحمد صالح', 'user_name_snap': 'علي',
        'over_limit': 0, 'in_locked_period': 0, 'device_id': deviceB, 'local_seq': 1,
      };
      expect(await env.ledger.importRow(row), true);
      expect(await env.ledger.importRow(row), false);
      expect(await env.ledger.importRow({...row, 'id': 'imp-1-dup'}), false,
          reason: 'different id but same device+seq must be ignored');
      expect((await env.ledger.balance(ahmed, Currency.yer)).balance.minor, 700);
    });
    test('local sequences of two devices do not collide', () async {
      await env.ledger.record(debit(1), worker); // deviceA seq 1
      final row = {
        'id': 'imp-b', 'shop_id': shopId, 'customer_id': ahmed, 'type': 'debit',
        'amount_minor': 1, 'currency_code': 'YER',
        'occurred_at': 1, 'recorded_at': 1, 'recorded_by': 'u', 'customer_name_snap': 'a',
        'user_name_snap': 'b', 'over_limit': 0, 'in_locked_period': 0,
        'device_id': deviceB, 'local_seq': 1,
      };
      expect(await env.ledger.importRow(row), true);
      expect((await env.ledger.balance(ahmed, Currency.yer)).txCount, 2);
    });
  });

  group('statement (edge #17, #1)', () {
    test('opening/closing consistency across a period', () async {
      final d0 = env.clock.now.subtract(const Duration(days: 40));
      final d1 = env.clock.now.subtract(const Duration(days: 20));
      final d2 = env.clock.now.subtract(const Duration(days: 10));
      await env.ledger.record(debit(10000, at: d0), worker); // before period
      await env.ledger.record(debit(3000, at: d1), worker);
      await env.ledger.record(credit(5000, at: d2), worker);
      await env.ledger.record(debit(2000), worker); // now (inside)

      final from = env.clock.now.subtract(const Duration(days: 30));
      final st = await env.ledger.statement(
          customerId: ahmed, currency: Currency.yer, from: from, to: env.clock.now);

      expect(st.opening.minor, 10000);
      expect(st.lines.length, 3);
      expect(st.totalDebit.minor, 5000);
      expect(st.totalCredit.minor, 5000);
      expect(st.closing.minor, 10000);
      // closing must equal the live balance when period ends now
      expect(st.closing, (await env.ledger.balance(ahmed, Currency.yer)).balance);
      // running balance sequence
      expect(st.lines.map((l) => l.runningBalance.minor).toList(), [13000, 8000, 10000]);
    });

    test('reversed pairs hidden by default, shown when requested, never affect running', () async {
      final tx = await env.ledger.record(debit(500), worker);
      await env.ledger.reverse(tx.id, owner, reason: 'x');
      await env.ledger.record(debit(200), worker);
      final from = env.clock.now.subtract(const Duration(days: 1));
      final hidden = await env.ledger.statement(
          customerId: ahmed, currency: Currency.yer, from: from, to: env.clock.now);
      expect(hidden.lines.length, 1);
      expect(hidden.closing.minor, 200);
      final shown = await env.ledger.statement(
          customerId: ahmed, currency: Currency.yer, from: from, to: env.clock.now, includeReversed: true);
      expect(shown.lines.length, 3);
      expect(shown.closing.minor, 200);
      // reversed original + its reversal do not move running balance
      expect(shown.lines[0].runningBalance.minor, 0);
      expect(shown.lines[1].runningBalance.minor, 0);
      expect(shown.lines[2].runningBalance.minor, 200);
    });

    test('same occurred_at ordered by recorded_at then id (edge #1)', () async {
      final at = env.clock.now.subtract(const Duration(hours: 1));
      final a = await env.ledger.record(debit(100, at: at), worker);
      env.clock.advance(const Duration(seconds: 1));
      final b = await env.ledger.record(credit(30, at: at), worker);
      final st = await env.ledger.statement(
          customerId: ahmed, currency: Currency.yer,
          from: at.subtract(const Duration(minutes: 1)), to: env.clock.now);
      expect(st.lines[0].tx.id, a.id);
      expect(st.lines[1].tx.id, b.id);
      expect(st.lines.last.runningBalance.minor, 70);
    });

    test('adjustments totals', () async {
      await env.ledger.record(debit(1000), worker);
      await env.ledger.record(
          NewTransaction(customerId: ahmed, type: TxType.adjustDown, amount: yer(100)), owner);
      final st = await env.ledger.statement(
          customerId: ahmed, currency: Currency.yer,
          from: env.clock.now.subtract(const Duration(days: 1)), to: env.clock.now);
      expect(st.totalAdjust.minor, -100);
      expect(st.closing.minor, 900);
    });
  });

  group('R3 cache & integrity', () {
    test('cache matches live after operations', () async {
      await env.ledger.record(debit(1000), worker);
      await env.ledger.record(credit(400), worker);
      final c = await env.db.query('balances_cache', where: 'customer_id=?', whereArgs: [ahmed]);
      expect(c.first['balance_minor'], 600);
      expect(await env.ledger.verifyIntegrity(), isEmpty);
    });
    test('verifyIntegrity detects a corrupted cache and rebuild fixes it', () async {
      await env.ledger.record(debit(1000), worker);
      await env.db.update('balances_cache', {'balance_minor': 5}, where: 'customer_id=?', whereArgs: [ahmed]);
      expect(await env.ledger.verifyIntegrity(), isNotEmpty);
      await env.ledger.rebuildCache();
      expect(await env.ledger.verifyIntegrity(), isEmpty);
      final c = await env.db.query('balances_cache', where: 'customer_id=?', whereArgs: [ahmed]);
      expect(c.first['balance_minor'], 1000);
    });
    test('cache after reversal', () async {
      final tx = await env.ledger.record(debit(1000), worker);
      await env.ledger.reverse(tx.id, owner, reason: 'r');
      final c = await env.db.query('balances_cache', where: 'customer_id=?', whereArgs: [ahmed]);
      expect(c.first['balance_minor'], 0);
      expect(c.first['tx_count'], 0);
    });
  });

  group('recent()', () {
    test('ordered newest first and paged', () async {
      for (var i = 0; i < 5; i++) {
        await env.ledger.record(debit(i + 1), worker);
        env.clock.advance(const Duration(minutes: 1));
      }
      final page1 = await env.ledger.recent(limit: 2);
      final page2 = await env.ledger.recent(limit: 2, offset: 2);
      expect(page1.map((t) => t.amount.minor).toList(), [5, 4]);
      expect(page2.map((t) => t.amount.minor).toList(), [3, 2]);
    });
  });

  group('stress: many transactions stay exact (R2)', () {
    test('1000 mixed entries sum exactly', () async {
      var expected = 0;
      for (var i = 1; i <= 1000; i++) {
        if (i % 3 == 0) {
          await env.ledger.record(credit(i), worker);
          expected -= i;
        } else {
          await env.ledger.record(debit(i), worker);
          expected += i;
        }
      }
      final b = await env.ledger.balance(ahmed, Currency.yer);
      expect(b.balance.minor, expected);
      expect(b.txCount, 1000);
      expect(await env.ledger.verifyIntegrity(), isEmpty);
    });
  });
}
