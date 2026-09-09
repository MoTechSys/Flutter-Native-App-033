import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'app_routes.dart';
import 'data/repositories/settings_repository.dart';
import 'data/session/session_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/onboarding_screen.dart';
import 'features/customers/customer_detail_screen.dart';
import 'features/backup/backup_screen.dart';
import 'features/customers/customers_screen.dart';
import 'features/documents/documents_screen.dart';
import 'features/help/voice_help_screen.dart';
import 'features/overdue/overdue_screen.dart';
import 'features/reports/reports_screen.dart';
import 'features/settings/activation_screen.dart';
import 'features/settings/currencies_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/workers/workers_screen.dart';
import 'features/home/home_screen.dart';
import 'features/transactions/new_transaction_flow.dart';
import 'features/transactions/transactions_screen.dart';
import 'features/transactions/tx_detail_screen.dart';
import 'shared/l10n/ar_strings.dart';
import 'shared/services/speech_service.dart';
import 'shared/theme/app_theme.dart';
import 'shared/widgets/app_back_button.dart';

class SijilApp extends StatelessWidget {
  const SijilApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsRepository>();
    return Provider<SpeechService>(
      create: (_) => SpeechService()
        ..enabled = settings.voiceEnabled
        ..setRate(settings.get<double>(SettingsRepository.kVoiceRate)),
      child: MaterialApp(
        title: S.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(settings.fontScale),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
        initialRoute: AppRoutes.home,
        onGenerateRoute: _onGenerateRoute,
      ),
    );
  }

  static Route<dynamic> _onGenerateRoute(RouteSettings s) {
    final arg = s.arguments;
    Widget page;
    switch (s.name) {
      case AppRoutes.home:
        page = const _Gate(child: HomeScreen());
      case AppRoutes.login:
        page = const LoginScreen();
      case AppRoutes.onboarding:
        page = const OnboardingScreen();
      case AppRoutes.customers:
        page = const _Gate(child: CustomersScreen());
      case AppRoutes.customerDetail:
        page = _Gate(child: CustomerDetailScreen(customerId: arg as String));
      case AppRoutes.newTransaction:
        page = _Gate(child: _NewTxLauncher(customerId: arg as String?));
      case AppRoutes.transactions:
        page = _Gate(child: TransactionsScreen(customerId: arg as String?));
      case AppRoutes.txDetail:
        page = _Gate(child: TxDetailScreen(txId: arg as String));
      case AppRoutes.overdue:
        page = const _Gate(child: OverdueScreen());
      case AppRoutes.reports:
        page = const _Gate(owner: true, child: ReportsScreen());
      case AppRoutes.currencies:
        page = const _Gate(owner: true, child: CurrenciesScreen());
      case AppRoutes.backup:
        page = const _Gate(owner: true, child: BackupScreen());
      case AppRoutes.workers:
        page = const _Gate(owner: true, child: WorkersScreen());
      case AppRoutes.settings:
        page = const _Gate(child: SettingsScreen());
      case AppRoutes.activation:
        page = const _Gate(owner: true, child: ActivationScreen());
      case AppRoutes.documents:
        page = _Gate(child: DocumentsScreen(customerId: arg as String?));
      case AppRoutes.voiceHelp:
        page = const VoiceHelpScreen();
      default:
        page = const _Gate(child: HomeScreen());
    }
    return MaterialPageRoute(builder: (_) => page, settings: s);
  }
}

/// No shop → onboarding. Shop but nobody logged in → login. Else the page.
class _Gate extends StatelessWidget {
  final Widget child;
  final bool owner;
  const _Gate({required this.child, this.owner = false});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    if (!session.hasShop) return const OnboardingScreen();
    if (!session.isLoggedIn) return const LoginScreen();
    if (owner && !session.isOwner) return const _OwnerOnly();
    return child;
  }
}

class _OwnerOnly extends StatelessWidget {
  const _OwnerOnly();
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(leading: const AppBackButton(), title: const Text('للمالك فقط')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lock_rounded, size: 72, color: Colors.grey),
              SizedBox(height: 12),
              Text('هذه الشاشة للمالك فقط', style: TextStyle(fontSize: 18)),
            ]),
          ),
        ),
      );
}

/// Route target for `/transactions/new`: starts the flow, then goes home.
class _NewTxLauncher extends StatefulWidget {
  final String? customerId;
  const _NewTxLauncher({this.customerId});

  @override
  State<_NewTxLauncher> createState() => _NewTxLauncherState();
}

class _NewTxLauncherState extends State<_NewTxLauncher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final saved = await NewTransactionFlow.start(context, customerId: widget.customerId);
      if (mounted) Navigator.pop(context, saved);
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
