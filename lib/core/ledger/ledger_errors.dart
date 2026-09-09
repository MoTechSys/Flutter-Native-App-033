/// Domain errors raised by the ledger. Each maps to a user-facing Arabic
/// message (`messageAr`) so the UI never shows raw exceptions.
sealed class LedgerError implements Exception {
  final String messageAr;
  const LedgerError(this.messageAr);
  @override
  String toString() => '$runtimeType: $messageAr';
}

class InvalidAmountError extends LedgerError {
  const InvalidAmountError() : super('المبلغ يجب أن يكون أكبر من صفر');
}

class InactiveCurrencyError extends LedgerError {
  final String code;
  const InactiveCurrencyError(this.code) : super('هذه العملة غير مفعّلة');
}

class FutureDateError extends LedgerError {
  const FutureDateError() : super('لا يمكن تسجيل حركة بتاريخ في المستقبل');
}

class LockedPeriodError extends LedgerError {
  const LockedPeriodError() : super('هذه الفترة مقفلة — يحتاج صلاحية المالك وسبباً');
}

class PermissionError extends LedgerError {
  const PermissionError() : super('ليس لديك صلاحية لهذه العملية');
}

class CustomerArchivedError extends LedgerError {
  const CustomerArchivedError() : super('الزبون مؤرشف — لا يمكن تسجيل أخذ جديد');
}

class CustomerNotFoundError extends LedgerError {
  const CustomerNotFoundError() : super('الزبون غير موجود');
}

class TransactionNotFoundError extends LedgerError {
  const TransactionNotFoundError() : super('الحركة غير موجودة');
}

class AlreadyReversedError extends LedgerError {
  const AlreadyReversedError() : super('هذه الحركة مُلغاة مسبقاً');
}

class CannotReverseReversalError extends LedgerError {
  const CannotReverseReversalError()
      : super('لا يمكن إلغاء قيد إلغاء — سجّل حركة جديدة بدلاً من ذلك');
}

class ReasonRequiredError extends LedgerError {
  const ReasonRequiredError() : super('سبب الإلغاء إلزامي');
}

class OpeningAlreadyExistsError extends LedgerError {
  const OpeningAlreadyExistsError()
      : super('يوجد رصيد افتتاحي لهذا الزبون بهذه العملة مسبقاً');
}

class IntegrityError extends LedgerError {
  const IntegrityError(String detail) : super('خلل في تكامل البيانات: $detail');
}
