import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'app_routes.dart';
import 'data/session/session_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/onboarding_screen.dart';
import 'features/customers/customer_detail_screen.dart';
import 'features/customers/customers_screen.dart';
import 'features/home/home_screen.dart';
import 'features/transactions/new_transaction_flow.dart';
import 'features/transactions/transactions_screen.dart';
import 'features/transactions/tx_detail_screen.dart';
import 'shared/l10n/ar_strings.dart';
import 'shared/services/speech_service.dart';
import 'shared/theme/app_theme.dart';
import 'shared/widgets/coming_soon_screen.dart';

class SijilApp extends StatelessWidget {
  const SijilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Provider<SpeechService>(
      create: (_) => SpeechService(),
      child: MaterialApp(
        title: S.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
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
        page = const ComingSoonScreen(title: S.overdue, phase: 'المرحلة 2');
      case AppRoutes.reports:
        page = const ComingSoonScreen(title: S.reports, phase: 'المرحلة 2');
      case AppRoutes.currencies:
        page = const ComingSoonScreen(title: S.currencies, phase: 'المرحلة 2');
      case AppRoutes.backup:
        page = const ComingSoonScreen(title: S.backup, phase: 'المرحلة 4');
      case AppRoutes.workers:
        page = const ComingSoonScreen(title: S.workers, phase: 'المرحلة 2');
      case AppRoutes.settings:
        page = const ComingSoonScreen(title: S.settings, phase: 'المرحلة 2');
      case AppRoutes.activation:
        page = const ComingSoonScreen(title: S.activation, phase: 'المرحلة 2');
      case AppRoutes.voiceHelp:
        page = const ComingSoonScreen(title: S.voiceHelp, phase: 'المرحلة 5');
      default:
        page = const _Gate(child: HomeScreen());
    }
    return MaterialPageRoute(builder: (_) => page, settings: s);
  }
}

/// No shop → onboarding. Shop but nobody logged in → login. Else the page.
class _Gate extends StatelessWidget {
  final Widget child;
  const _Gate({required this.child});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    if (!session.hasShop) return const OnboardingScreen();
    if (!session.isLoggedIn) return const LoginScreen();
    return child;
  }
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
