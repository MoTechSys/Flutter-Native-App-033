/// Transaction kinds (docs/04_LEDGER_RULES.md §2).
///
/// `sign` is the effect on the customer's balance where a POSITIVE balance
/// means the customer owes the shop.
enum TxType {
  /// أخذ مني — customer took goods on credit.
  debit('debit', 1, 'أخذ'),

  /// دفع لي — customer paid.
  credit('credit', -1, 'دفع'),

  /// تسوية بالنقصان — discount / waiver in favour of the customer (owner only).
  adjustDown('adjust_down', -1, 'تسوية (خصم)'),

  /// تسوية بالزيادة — correction in favour of the shop (owner only, rare).
  adjustUp('adjust_up', 1, 'تسوية (زيادة)'),

  /// رصيد افتتاحي — carried from the paper ledger (owner, once per customer+currency).
  opening('opening', 1, 'رصيد سابق');

  final String dbValue;
  final int sign;
  final String labelAr;
  const TxType(this.dbValue, this.sign, this.labelAr);

  static TxType fromDb(String v) =>
      TxType.values.firstWhere((t) => t.dbValue == v,
          orElse: () => throw ArgumentError('Unknown tx type: $v'));

  /// The type that exactly cancels this one (R1 reversal).
  TxType get reverse {
    switch (this) {
      case TxType.debit:
        return TxType.credit;
      case TxType.credit:
        return TxType.debit;
      case TxType.adjustDown:
        return TxType.adjustUp;
      case TxType.adjustUp:
        return TxType.adjustDown;
      case TxType.opening:
        // An opening balance is reversed by an adjustment down of equal size.
        return TxType.adjustDown;
    }
  }

  bool get ownerOnly =>
      this == TxType.adjustDown || this == TxType.adjustUp || this == TxType.opening;
}
