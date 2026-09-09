import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../core/ledger/tx_type.dart';
import '../../data/repositories/settings_repository.dart';
import 'ar_strings.dart';

/// D11: the took/paid words are editable in settings; every screen reads them
/// from here instead of hard-coding [S.tookFromMe] / [S.paidToMe].
class TxLabels {
  TxLabels._();

  static String took(BuildContext context) =>
      context.read<SettingsRepository>().labelTook;
  static String paid(BuildContext context) =>
      context.read<SettingsRepository>().labelPaid;

  static String of(BuildContext context, TxType t) => switch (t) {
        TxType.debit => took(context),
        TxType.credit => paid(context),
        TxType.adjustDown => S.adjustDown,
        TxType.adjustUp => S.adjustUp,
        TxType.opening => 'رصيد سابق',
      };
}
