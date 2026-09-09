import '../money/currency.dart';
import '../money/money.dart';
import 'tx_type.dart';

/// Who is acting. Permissions are resolved by the caller (auth layer) and
/// passed in so the ledger stays pure and testable.
class Actor {
  final String userId;
  final String name;
  final bool isOwner;
  final bool canReverse;
  final bool canAdjust;
  final bool canBackdateIntoLocked;

  const Actor({
    required this.userId,
    required this.name,
    required this.isOwner,
    bool? canReverse,
    bool? canAdjust,
    bool? canBackdateIntoLocked,
  })  : canReverse = canReverse ?? isOwner,
        canAdjust = canAdjust ?? isOwner,
        canBackdateIntoLocked = canBackdateIntoLocked ?? isOwner;

  const Actor.owner(this.userId, this.name)
      : isOwner = true,
        canReverse = true,
        canAdjust = true,
        canBackdateIntoLocked = true;

  const Actor.worker(this.userId, this.name)
      : isOwner = false,
        canReverse = false,
        canAdjust = false,
        canBackdateIntoLocked = false;
}

/// Input to record a new transaction.
class NewTransaction {
  final String customerId;
  final TxType type;
  final Money amount;
  final DateTime? occurredAt; // default: now
  final String? noteText;
  final String? noteVoicePath;
  final String? receiptPhotoPath;
  final DateTime? dueDate;
  final String? lockedReason; // required when backdating into a locked period

  const NewTransaction({
    required this.customerId,
    required this.type,
    required this.amount,
    this.occurredAt,
    this.noteText,
    this.noteVoicePath,
    this.receiptPhotoPath,
    this.dueDate,
    this.lockedReason,
  });
}

/// A stored transaction row.
class LedgerTx {
  final String id;
  final String shopId;
  final String customerId;
  final TxType type;
  final Money amount;
  final DateTime occurredAt;
  final DateTime recordedAt;
  final String recordedBy;
  final String? noteText;
  final String? noteVoicePath;
  final String? receiptPhotoPath;
  final DateTime? dueDate;
  final String? reversesId;
  final String? reversedById;
  final String? reversalReason;
  final String customerNameSnap;
  final String userNameSnap;
  final bool overLimit;
  final bool inLockedPeriod;
  final String deviceId;
  final int localSeq;

  const LedgerTx({
    required this.id,
    required this.shopId,
    required this.customerId,
    required this.type,
    required this.amount,
    required this.occurredAt,
    required this.recordedAt,
    required this.recordedBy,
    this.noteText,
    this.noteVoicePath,
    this.receiptPhotoPath,
    this.dueDate,
    this.reversesId,
    this.reversedById,
    this.reversalReason,
    required this.customerNameSnap,
    required this.userNameSnap,
    required this.overLimit,
    required this.inLockedPeriod,
    required this.deviceId,
    required this.localSeq,
  });

  bool get isReversed => reversedById != null;
  bool get isReversal => reversesId != null;

  /// Signed effect on the customer's balance (positive = owes more).
  Money get signedEffect => Money(type.sign * amount.minor, amount.currency);

  factory LedgerTx.fromRow(Map<String, Object?> r) {
    final cur = Currency.byCode(r['currency_code'] as String);
    return LedgerTx(
      id: r['id'] as String,
      shopId: r['shop_id'] as String,
      customerId: r['customer_id'] as String,
      type: TxType.fromDb(r['type'] as String),
      amount: Money(r['amount_minor'] as int, cur),
      occurredAt:
          DateTime.fromMillisecondsSinceEpoch(r['occurred_at'] as int, isUtc: true),
      recordedAt:
          DateTime.fromMillisecondsSinceEpoch(r['recorded_at'] as int, isUtc: true),
      recordedBy: r['recorded_by'] as String,
      noteText: r['note_text'] as String?,
      noteVoicePath: r['note_voice_path'] as String?,
      receiptPhotoPath: r['receipt_photo_path'] as String?,
      dueDate: r['due_date'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(r['due_date'] as int, isUtc: true),
      reversesId: r['reverses_id'] as String?,
      reversedById: r['reversed_by_id'] as String?,
      reversalReason: r['reversal_reason'] as String?,
      customerNameSnap: r['customer_name_snap'] as String,
      userNameSnap: r['user_name_snap'] as String,
      overLimit: (r['over_limit'] as int) == 1,
      inLockedPeriod: (r['in_locked_period'] as int) == 1,
      deviceId: r['device_id'] as String,
      localSeq: r['local_seq'] as int,
    );
  }
}

/// Balance of one customer in one currency (R4: never mixed).
class CustomerBalance {
  final String customerId;
  final Money balance;
  final int txCount;
  final DateTime? lastTxAt;
  const CustomerBalance({
    required this.customerId,
    required this.balance,
    required this.txCount,
    this.lastTxAt,
  });

  /// Customer owes the shop.
  bool get owes => balance.isPositive;

  /// Shop owes the customer (paid in advance).
  bool get inCredit => balance.isNegative;
}

/// Statement for one customer, one currency, one period.
class Statement {
  final String customerId;
  final Currency currency;
  final DateTime from;
  final DateTime to;
  final Money opening;
  final List<StatementLine> lines;
  final Money closing;
  final Money totalDebit;
  final Money totalCredit;
  final Money totalAdjust;

  const Statement({
    required this.customerId,
    required this.currency,
    required this.from,
    required this.to,
    required this.opening,
    required this.lines,
    required this.closing,
    required this.totalDebit,
    required this.totalCredit,
    required this.totalAdjust,
  });
}

class StatementLine {
  final LedgerTx tx;
  final Money runningBalance;
  const StatementLine(this.tx, this.runningBalance);
}
