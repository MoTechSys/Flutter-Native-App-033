/// Named routes = the 9 drawer paths + sub-screens (docs/05 §1, docs/03 §6.2).
class AppRoutes {
  AppRoutes._();

  static const home = '/';
  static const login = '/login';
  static const onboarding = '/onboarding';
  static const txDetail = '/transactions/detail';
  static const customers = '/customers';
  static const customerDetail = '/customers/detail';
  static const newTransaction = '/transactions/new';
  static const transactions = '/transactions';
  static const overdue = '/overdue';
  static const reports = '/reports';
  static const currencies = '/currencies';
  static const backup = '/backup';
  static const workers = '/workers';
  static const settings = '/settings';
  static const activation = '/settings/activation';
  static const voiceHelp = '/help/voice';
}
