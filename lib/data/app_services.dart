import 'package:flutter/foundation.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../core/ledger/ledger_service.dart';
import 'repositories/customer_repository.dart';
import 'repositories/dashboard_repository.dart';
import 'repositories/transactions_repository.dart';
import 'session/session_provider.dart';

/// Shop-scoped services. They need a `shopId`, which only exists after
/// onboarding, so they are built lazily from [SessionProvider].
class AppServices extends ChangeNotifier {
  final Database db;
  final String deviceId;
  final SessionProvider session;

  String? _shopId;
  LedgerService? _ledger;
  CustomerRepository? _customers;
  TransactionsRepository? _transactions;
  DashboardRepository? _dashboard;

  AppServices({required this.db, required this.deviceId, required this.session}) {
    session.addListener(_onSession);
    _onSession();
  }

  void _onSession() {
    final id = session.shop?.id;
    if (id == null || id == _shopId) return;
    _shopId = id;
    _ledger = LedgerService(db: db, shopId: id, deviceId: deviceId);
    _customers = CustomerRepository(db, shopId: id, deviceId: deviceId);
    _transactions = TransactionsRepository(db);
    _dashboard = DashboardRepository(db, _ledger!);
    notifyListeners();
  }

  bool get ready => _ledger != null;

  LedgerService get ledger => _ledger ?? (throw StateError('no shop yet'));
  CustomerRepository get customers => _customers ?? (throw StateError('no shop yet'));
  TransactionsRepository get transactions => _transactions ?? (throw StateError('no shop yet'));
  DashboardRepository get dashboard => _dashboard ?? (throw StateError('no shop yet'));

  @override
  void dispose() {
    session.removeListener(_onSession);
    super.dispose();
  }
}
