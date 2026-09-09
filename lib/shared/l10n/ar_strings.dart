/// All user-facing Arabic strings. Single language for now (docs/05 §8).
class S {
  S._();

  static const appName = 'سِجِل';
  static const appNamePlain = 'سجل';

  // Drawer / routes
  static const home = 'الرئيسية';
  static const customers = 'الزباين';
  static const transactions = 'الحركات';
  static const overdue = 'المتأخرين';
  static const reports = 'التقارير';
  static const currencies = 'العملات';
  static const backup = 'النسخة الاحتياطية';
  static const workers = 'العمال';
  static const settings = 'الإعدادات';
  static const activation = 'التفعيل';
  static const voiceHelp = 'مساعدة صوتية';
  static const owner = 'مالك';
  static const worker = 'عامل';
  static const activated = 'مفعّل';
  static const trial = 'تجريبي';

  // Home
  static const owedToYou = 'لك عند الناس';
  static const today = 'اليوم';
  static const newTransaction = 'عملية';
  static const newTransactionFull = 'عملية جديدة';
  static const recentTransactions = 'آخر الحركات';
  static const seeAll = 'الكل';
  static const noTransactionsYet = 'لا توجد حركات بعد';

  // Tx types
  static const took = 'أخذ مني';
  static const paid = 'دفع لي';
  static const owes = 'عليه';
  static const inCredit = 'له';
  static const settled = 'مسدَّد';

  // Filters
  static const all = 'الكل';
  static const tookFilter = 'أخذوا';
  static const paidFilter = 'دفعوا';
  static const yesterday = 'أمس';

  // Customers
  static const addCustomer = 'زبون جديد';
  static const customerName = 'اسم الزبون';
  static const phone = 'رقم الهاتف';
  static const phoneOptional = 'رقم الهاتف (اختياري)';
  static const note = 'ملاحظة';
  static const takePhoto = 'صورة';
  static const search = 'بحث';
  static const noCustomers = 'لا يوجد زباين بعد';
  static const addFirstCustomer = 'أضف أول زبون';
  static const owingFilter = 'عليهم';
  static const overdueFilter = 'متأخرين';
  static const settledFilter = 'مسدَّد';
  static const sortRecent = 'الأحدث تعاملاً';
  static const sortAlpha = 'أبجدي';
  static const sortDebt = 'الأكبر ديناً';
  static const balance = 'الرصيد';
  static const noDebt = 'لا شيء عليه';
  static const edit = 'تعديل';
  static const archive = 'أرشفة';
  static const unarchive = 'إلغاء الأرشفة';
  static const archived = 'مؤرشف';
  static const whatsapp = 'واتساب';
  static const sms = 'رسالة';
  static const statement = 'كشف';
  static const took1 = 'أخذ';
  static const paid1 = 'دفع';
  static const noPhone = 'لا يوجد رقم هاتف';
  static const save = 'حفظ';
  static const cancel = 'إلغاء';
  static const back = 'تراجع';
  static const next = 'التالي';
  static const done = 'تم';
  static const nameRequired = 'الاسم مطلوب';
  static const reminderSent = 'تم تسجيل التذكير';

  // New transaction
  static const chooseCustomer = 'اختر الزبون';
  static const recentCustomers = 'الأخيرون';
  static const allCustomers = 'كل الزباين';
  static const chooseType = 'ماذا حدث؟';
  static const tookFromMe = 'أخذ مني';
  static const paidToMe = 'دفع لي';
  static const adjustment = 'تسوية';
  static const adjustDown = 'تخفيض الدين';
  static const adjustUp = 'زيادة الدين';
  static const amount = 'المبلغ';
  static const banknotes = 'أوراق';
  static const keypad = 'أرقام';
  static const selectedNotes = 'الأوراق المختارة';
  static const clear = 'مسح';
  static const confirm = 'تأكيد';
  static const currentBalance = 'عليه الآن';
  static const newBalance = 'يصير عليه';
  static const willBeInCredit = 'يصير له';
  static const saved = 'تم الحفظ';
  static const undo = 'تراجع';
  static const undone = 'تم التراجع';
  static const addNote = 'ملاحظة';
  static const receiptPhoto = 'صورة فاتورة';
  static const dueDate = 'موعد السداد';
  static const amountZero = 'أدخل المبلغ';
  static const listen = 'اسمع';

  // Transactions list / detail
  static const txDetails = 'تفاصيل الحركة';
  static const reverse = 'عكس الحركة';
  static const reverseReason = 'سبب العكس';
  static const reversed = 'معكوسة';
  static const reversal = 'قيد عكسي';
  static const recordedBy = 'سجّلها';
  static const at = 'في';
  static const noResults = 'لا توجد نتائج';
  static const loadMore = 'المزيد';
  static const undoByUser = 'تراجع المستخدم';

  // Login / onboarding
  static const whoAreYou = 'من أنت؟';
  static const enterPin = 'أدخل الرمز';
  static const wrongPin = 'الرمز غير صحيح';
  static const welcome = 'مرحباً بك في سِجِل';
  static const shopName = 'اسم المحل';
  static const yourName = 'اسمك';
  static const setPinOptional = 'رمز دخول (4 أرقام، اختياري)';
  static const start = 'ابدأ';
  static const logout = 'تسجيل خروج';

  // Generic
  static const comingSoon = 'قريباً';
  static const comingSoonBody = 'هذه الشاشة ضمن المرحلة التالية من الخطة.';
  static const version = 'الإصدار';
}
