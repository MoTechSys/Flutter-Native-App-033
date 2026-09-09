import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_routes.dart';
import 'features/home/home_screen.dart';
import 'shared/l10n/ar_strings.dart';
import 'shared/theme/app_theme.dart';
import 'shared/widgets/coming_soon_screen.dart';

class SijilApp extends StatelessWidget {
  const SijilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
    );
  }

  static Route<dynamic> _onGenerateRoute(RouteSettings s) {
    Widget page;
    switch (s.name) {
      case AppRoutes.home:
        page = const HomeScreen();
      case AppRoutes.customers:
      case AppRoutes.customerDetail:
        page = const ComingSoonScreen(title: S.customers, phase: 'المرحلة 1');
      case AppRoutes.newTransaction:
        page = const ComingSoonScreen(title: S.newTransactionFull, phase: 'المرحلة 1');
      case AppRoutes.transactions:
        page = const ComingSoonScreen(title: S.transactions, phase: 'المرحلة 1');
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
        page = const HomeScreen();
    }
    return MaterialPageRoute(builder: (_) => page, settings: s);
  }
}
