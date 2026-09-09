import 'dart:typed_data';

import '../ledger/ledger_models.dart';
import '../money/currency.dart';
import '../money/money.dart';

/// Shop identity printed in every header (docs/09 §4 header.fields).
class DocShop {
  final String name;
  final String? address;
  final String? phone;
  final String? extraLine;
  final Uint8List? logoBytes;
  const DocShop({required this.name, this.address, this.phone, this.extraLine, this.logoBytes});
}

class DocCustomer {
  final String name;
  final String? phone;
  final String? idNumber; // for debt_ack
  const DocCustomer({required this.name, this.phone, this.idNumber});
}

/// Everything a statement needs — one section per currency (docs/09 §7).
class StatementDoc {
  final DocShop shop;
  final DocCustomer customer;
  final List<Statement> sections;
  final bool detailed;
  final DateTime issuedAt;
  final bool watermarkTrial;
  const StatementDoc({
    required this.shop,
    required this.customer,
    required this.sections,
    required this.detailed,
    required this.issuedAt,
    this.watermarkTrial = false,
  });
}

class ReceiptDoc {
  final DocShop shop;
  final DocCustomer customer;
  final String receiptNo; // e.g. local_seq or short id
  final LedgerTx payment;
  final Money balanceAfter;
  final String? receivedBy;
  final DateTime issuedAt;
  final bool watermarkTrial;
  const ReceiptDoc({
    required this.shop,
    required this.customer,
    required this.receiptNo,
    required this.payment,
    required this.balanceAfter,
    this.receivedBy,
    required this.issuedAt,
    this.watermarkTrial = false,
  });
}

class ClaimDoc {
  final DocShop shop;
  final DocCustomer customer;
  final Map<Currency, Money> balances;
  final DateTime? lastPaymentAt;
  final int payWithinDays;
  final DateTime issuedAt;
  final bool watermarkTrial;
  const ClaimDoc({
    required this.shop,
    required this.customer,
    required this.balances,
    required this.lastPaymentAt,
    this.payWithinDays = 7,
    required this.issuedAt,
    this.watermarkTrial = false,
  });
}

class OverdueRow {
  final String name;
  final String? phone;
  final Money balance;
  final DateTime? lastPaymentAt;
  final int daysOverdue;
  const OverdueRow({required this.name, this.phone, required this.balance, required this.lastPaymentAt, required this.daysOverdue});
}

class OverdueReportDoc {
  final DocShop shop;
  final Currency currency;
  final List<OverdueRow> rows;
  final DateTime issuedAt;
  final bool watermarkTrial;
  const OverdueReportDoc({
    required this.shop,
    required this.currency,
    required this.rows,
    required this.issuedAt,
    this.watermarkTrial = false,
  });
}

class DebtAckDoc {
  final DocShop shop;
  final DocCustomer customer;
  final Money amount;
  final DateTime? payBy;
  final DateTime issuedAt;
  final bool watermarkTrial;
  const DebtAckDoc({
    required this.shop,
    required this.customer,
    required this.amount,
    required this.payBy,
    required this.issuedAt,
    this.watermarkTrial = false,
  });
}
