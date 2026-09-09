# 04 — قواعد الحسابات (الدفتر) ومخطط البيانات

> **هذا الملف قانون.** أي كود يلمس المال يلتزم به حرفياً. أي استثناء يُناقَش ويُوثَّق هنا أولاً.
> الكود المطابق: `lib/core/money/`, `lib/core/ledger/`, `lib/core/db/schema.dart`. الاختبارات: `test/ledger/`.

## القواعد العشر

### R1 — الدفتر إلحاقي فقط (Append-Only)
- **لا `UPDATE` ولا `DELETE`** على جدول `transactions` أبداً. (مُطبَّق بـ SQLite triggers ترفض التعديل/الحذف).
- التصحيح = **قيد عكسي** (`reversal`) جديد: نفس المبلغ، نوع معكوس، `reverses_id` يشير للأصل، والأصل يُعلَّم `reversed_by_id` (هذا الحقل الوحيد المسموح تعديله — عبر دالة واحدة محمية).
- **الأثر:** كل حالة تاريخية قابلة لإعادة البناء. الزبون لا يستطيع القول "ما أخذت" والمالك لا يستطيع "تعديل" الماضي بصمت.

### R2 — المال أعداد صحيحة (Integer Minor Units)
- `amount_minor INTEGER` — **لا `double` أبداً** في التخزين أو الحساب.
- الريال اليمني: `minor_units = 0` (1 ريال = 1). السعودي/الدولار: `minor_units = 2` (1 = 100 هللة/سنت).
- كائن `Money(amountMinor, currency)` — الجمع/الطرح فقط بين نفس العملة، وإلا `CurrencyMismatchError`.
- الضرب (سعر صرف) يستخدم كسراً `rate_num/rate_den` ثم تقريب مصرفي (`round half even`) — **للعرض فقط**.

### R3 — الرصيد يُحسَب، لا يُخزَّن كمصدر حقيقة
- `balance = Σ(debit) − Σ(credit) ± Σ(adjust)` لكل (زبون، عملة) من الحركات **غير المعكوسة**.
- يجوز **cache** في جدول `balances_cache` للسرعة، لكن:
  - يُعاد بناؤه كاملاً عند: فتح التطبيق، بعد أي مزامنة، عند أي اختلاف في فحص التكامل.
  - دالة `verifyIntegrity()` تقارن الـcache بالحساب الفعلي وتسجّل أي انحراف في `08_ERRORS`.

### R4 — كل عملة دفتر مستقل
- لا تُجمع عملتان في رقم واحد أبداً. "عليه 50,000 ر.ي و 100 ر.س" — سطران.
- بطاقة البطل تعرض العملة الرئيسية كبيرة والباقي أسطراً صغيرة.
- التحويل الإجمالي "التقريبي" اختياري ويُعلَّم بـ"≈" دائماً.

### R5 — معرّفات UUID v4
- كل سجل `id TEXT PRIMARY KEY` = UUID v4. لا `AUTOINCREMENT` للكيانات.
- السبب: أجهزة متعددة أوفلاين تُنشئ سجلات بلا تصادم.

### R6 — مفتاح التكرار (Idempotency)
- كل حركة: `device_id TEXT` + `local_seq INTEGER` مع `UNIQUE(device_id, local_seq)`.
- الاستيراد/المزامنة تستخدم `INSERT OR IGNORE` — نفس الحركة لا تُضاف مرتين مهما تكررت.

### R7 — وقتان
- `occurred_at` (ميلي ثانية UTC): وقت الحدث الفعلي كما يختاره المستخدم (افتراضي: الآن). للترتيب في الكشوف والتقارير.
- `recorded_at` (ميلي ثانية UTC): وقت الجهاز لحظة الحفظ. **لا يُعدَّل**. للتدقيق.
- `occurred_at` لا يجوز أن يكون في المستقبل (> الآن + 5 دقائق تسامحاً لفرق الساعات) → `FutureDateError`.
- **قفل الفترة:** لو `occurred_at` داخل فترة مقفلة (`settings.locked_before`) → يُرفض إلا للمالك مع سبب.

### R8 — لقطات (Snapshots)
- الحركة تحفظ: `customer_name_snap`, `user_name_snap`, `fx_rate_snap` (إن وُجد).
- الكشف المطبوع قديماً يبقى مطابقاً لما طُبع.

### R9 — الإلغاء محكوم
- العامل **لا يملك** صلاحية الإلغاء. المالك فقط (`perms.can_reverse`).
- الإلغاء يتطلب `reversal_reason` غير فارغ (نص أو مسار صوت).
- لا يجوز عكس حركة معكوسة. لا يجوز عكس قيد عكسي (بل تُسجَّل حركة جديدة).
- في الكشف: الحركة الأصلية تظهر مشطوبة + القيد العكسي تحتها، أو تُخفى الاثنتان حسب خيار "إظهار المُلغى".

### R10 — كل قاعدة لها اختبار
- `test/ledger/` يجب أن يغطي: كل قاعدة أعلاه + حالات الحافة في القسم 3 أدناه.
- CI محلي: `flutter test test/ledger` قبل كل commit يلمس `core/`.

## 2. أنواع الحركات
| `type` | المعنى | أثره على الرصيد (عليه) | من يسجّله |
|---|---|---|---|
| `debit` | **أخذ مني** — الزبون أخذ بضاعة/خدمة بالدَّين | **+** amount | عامل، مالك |
| `credit` | **دفع لي** — الزبون سدّد | **−** amount | عامل، مالك |
| `adjust_down` | **تسوية بالنقصان** — خصم/تنازل/تصحيح لصالح الزبون | **−** amount | مالك فقط |
| `adjust_up` | **تسوية بالزيادة** — تصحيح لصالح المحل (نادر) | **+** amount | مالك فقط |
| `opening` | **رصيد افتتاحي** — منقول من الدفتر الورقي عند إضافة زبون قديم | **+** amount (أو − لو له رصيد) | مالك؛ مرة واحدة لكل (زبون، عملة) |

`amount_minor > 0` دائماً (CHECK). الاتجاه يحدده `type`، لا الإشارة.
الرصيد الموجب = الزبون **مدين** للمحل (عليه). السالب = المحل مدين للزبون (له) — يظهر بالأخضر مع كلمة "له".

## 3. حالات الحافة (كلها في الاختبارات)
1. حركتان بنفس `occurred_at` → الترتيب الثانوي بـ`recorded_at` ثم `rowid` (ترتيب الإدخال الفعلي — **ليس** `id` لأن UUID عشوائي).
2. مبلغ 0 → مرفوض `InvalidAmountError`.
3. مبلغ سالب → مرفوض.
4. عملة غير مفعّلة → مرفوض.
5. `credit` أكبر من الرصيد → **مسموح** (الزبون دفع مقدماً → رصيد سالب "له"). تنبيه صوتي فقط.
6. عكس حركة معكوسة → مرفوض `AlreadyReversedError`.
7. عكس بدون سبب → مرفوض.
8. عكس بصلاحية عامل → مرفوض `PermissionError`.
9. استيراد نفس (`device_id`,`local_seq`) مرتين → الثانية تُهمَل، الرصيد لا يتغير.
10. `occurred_at` مستقبلي → مرفوض.
11. `occurred_at` في فترة مقفلة (عامل) → مرفوض؛ (مالك بسبب) → مقبول ويُعلَّم.
12. رصيد افتتاحي ثانٍ لنفس (زبون، عملة) → مرفوض.
13. زبون مؤرشف → لا حركات جديدة (إلا `credit` لتسديد ما عليه).
14. تجاوز `credit_limit` → مسموح مع علم `over_limit=1` وتنبيه.
15. جمع `Money` بعملتين → استثناء.
16. تنسيق 1234567 → "1,234,567"؛ −500 → "−500"؛ SAR 12345 minor → "123.45".
17. كشف حساب بفترة: الرصيد الافتتاحي للفترة = مجموع ما قبلها؛ الختامي = الافتتاحي + حركات الفترة؛ يجب أن يساوي الرصيد الكلي إن كانت الفترة حتى الآن.
18. مجموعة عائلية: رصيد المجموعة = Σ أرصدة الأعضاء لكل عملة.
19. تقادم الديون: عمر الدين = من آخر حركة `debit` غير مسددة بالكامل (FIFO تقريبي: نقيس من تاريخ آخر مرة كان الرصيد ≤ 0، أو من الافتتاحي).
20. حذف زبون → **غير موجود**؛ أرشفة فقط.

## 4. مخطط قاعدة البيانات (SQLite) — الإصدار 1
```sql
PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

CREATE TABLE shops (
  id TEXT PRIMARY KEY, name TEXT NOT NULL, logo_path TEXT, address TEXT, phone TEXT,
  extra_line TEXT, created_at INTEGER NOT NULL
);
CREATE TABLE users (
  id TEXT PRIMARY KEY, shop_id TEXT NOT NULL REFERENCES shops(id),
  name TEXT NOT NULL, photo_path TEXT, role TEXT NOT NULL CHECK(role IN ('owner','worker')),
  pin_hash TEXT, pin_salt TEXT, perms_json TEXT NOT NULL DEFAULT '{}',
  is_active INTEGER NOT NULL DEFAULT 1, created_at INTEGER NOT NULL
);
CREATE TABLE currencies (
  code TEXT PRIMARY KEY, name_ar TEXT NOT NULL, symbol TEXT NOT NULL,
  minor_units INTEGER NOT NULL CHECK(minor_units IN (0,2)),
  is_active INTEGER NOT NULL DEFAULT 0, is_primary INTEGER NOT NULL DEFAULT 0, sort INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE fx_rates (
  id TEXT PRIMARY KEY, from_code TEXT NOT NULL, to_code TEXT NOT NULL,
  rate_num INTEGER NOT NULL, rate_den INTEGER NOT NULL, set_at INTEGER NOT NULL, set_by TEXT
);
CREATE TABLE customers (
  id TEXT PRIMARY KEY, shop_id TEXT NOT NULL REFERENCES shops(id),
  name TEXT NOT NULL, phone TEXT, photo_path TEXT, voice_name_path TEXT,
  family_group_id TEXT, credit_limit_minor INTEGER, credit_limit_currency TEXT,
  note TEXT, is_archived INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, updated_by TEXT,
  last_activity_at INTEGER
);
CREATE TABLE transactions (
  id TEXT PRIMARY KEY, shop_id TEXT NOT NULL, customer_id TEXT NOT NULL REFERENCES customers(id),
  type TEXT NOT NULL CHECK(type IN ('debit','credit','adjust_down','adjust_up','opening')),
  amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
  currency_code TEXT NOT NULL REFERENCES currencies(code),
  occurred_at INTEGER NOT NULL, recorded_at INTEGER NOT NULL, recorded_by TEXT NOT NULL,
  note_text TEXT, note_voice_path TEXT, receipt_photo_path TEXT, due_date INTEGER,
  reverses_id TEXT REFERENCES transactions(id),
  reversed_by_id TEXT,
  reversal_reason TEXT,
  customer_name_snap TEXT NOT NULL, user_name_snap TEXT NOT NULL, fx_rate_snap TEXT,
  over_limit INTEGER NOT NULL DEFAULT 0, in_locked_period INTEGER NOT NULL DEFAULT 0,
  device_id TEXT NOT NULL, local_seq INTEGER NOT NULL,
  UNIQUE(device_id, local_seq)
);
CREATE INDEX idx_tx_customer_time ON transactions(customer_id, occurred_at DESC, recorded_at DESC);
CREATE INDEX idx_tx_time ON transactions(occurred_at DESC);
CREATE INDEX idx_tx_user ON transactions(recorded_by, occurred_at DESC);
CREATE INDEX idx_cust_active_name ON customers(shop_id, is_archived, name);
CREATE INDEX idx_cust_activity ON customers(shop_id, is_archived, last_activity_at DESC);

-- R1 enforcement: forbid UPDATE/DELETE except setting reversed_by_id once
CREATE TRIGGER trg_tx_no_delete BEFORE DELETE ON transactions
BEGIN SELECT RAISE(ABORT, 'transactions are append-only'); END;
CREATE TRIGGER trg_tx_no_update BEFORE UPDATE ON transactions
WHEN NOT (OLD.reversed_by_id IS NULL AND NEW.reversed_by_id IS NOT NULL
          AND NEW.id = OLD.id AND NEW.amount_minor = OLD.amount_minor AND NEW.type = OLD.type
          AND NEW.customer_id = OLD.customer_id AND NEW.currency_code = OLD.currency_code
          AND NEW.occurred_at = OLD.occurred_at AND NEW.recorded_at = OLD.recorded_at)
BEGIN SELECT RAISE(ABORT, 'transactions are immutable'); END;

CREATE TABLE balances_cache (
  customer_id TEXT NOT NULL, currency_code TEXT NOT NULL,
  balance_minor INTEGER NOT NULL, tx_count INTEGER NOT NULL, last_tx_at INTEGER,
  computed_at INTEGER NOT NULL, PRIMARY KEY(customer_id, currency_code)
);
CREATE TABLE reminders (
  id TEXT PRIMARY KEY, customer_id TEXT NOT NULL, channel TEXT NOT NULL CHECK(channel IN ('wa','sms','print')),
  balance_snap_minor INTEGER NOT NULL, currency_code TEXT NOT NULL,
  sent_at INTEGER NOT NULL, sent_by TEXT NOT NULL, template_id TEXT
);
CREATE TABLE audit_log (
  id TEXT PRIMARY KEY, entity TEXT NOT NULL, entity_id TEXT NOT NULL, action TEXT NOT NULL,
  actor_id TEXT, at INTEGER NOT NULL, before_json TEXT, after_json TEXT, device_id TEXT NOT NULL
);
CREATE TABLE doc_templates (
  id TEXT PRIMARY KEY, name_ar TEXT NOT NULL,
  kind TEXT NOT NULL CHECK(kind IN ('statement','statement_detailed','receipt','claim','overdue_report','debt_ack')),
  layout_json TEXT NOT NULL, is_default INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL
);
CREATE TABLE settings (key TEXT PRIMARY KEY, value_json TEXT NOT NULL);
CREATE TABLE sync_state (
  device_id TEXT PRIMARY KEY, device_name TEXT, last_export_seq INTEGER NOT NULL DEFAULT 0,
  last_import_at INTEGER, drive_file_id TEXT, is_frozen INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE schema_meta (version INTEGER NOT NULL);
```

### العملات المُعرَّفة مسبقاً
| code | name_ar | symbol | minor | ملاحظة |
|---|---|---|---|---|
| `YER` | ريال يمني (جديد/عدن) | ر.ي | 0 | — |
| `YER_OLD` | ريال يمني (قديم/صنعاء) | ر.ي ق | 0 | نفس الاسم عملياً لكن سعر مختلف — يظهر كعملة منفصلة |
| `SAR` | ريال سعودي | ر.س | 2 | |
| `USD` | دولار أمريكي | $ | 2 | |

المحل يفعّل ما يستخدمه ويختار **الرئيسية** (افتراضي `YER`).

## 5. الترحيلات (Migrations)
`schema_meta.version` — كل تغيير مستقبلي = ملف `migration_vN.dart` + تحديث هذا القسم. **لا تعديل على الترحيلات القديمة.**
| v | التغيير | التاريخ |
|---|---|---|
| 1 | المخطط الأولي أعلاه | جلسة 1 |
