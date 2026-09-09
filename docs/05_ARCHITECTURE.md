# 05 — هيكلية المستودع والمعمارية

## 1. هيكلية المستودع
```
flutter_app/
├── docs/                          ← ذاكرة المشروع (هذا المجلد)
│   ├── 00_START_HERE.md … 09_DOCUMENTS_SPEC.md
│   ├── design/mockups/            ← الصور المعتمدة + alternatives/
│   ├── design/pdf_poc_*           ← إثبات PDF عربي
│   └── research/                  ← مواد خام (تحليل إكسل، إلخ)
├── assets/
│   ├── fonts/  Tajawal-Regular/Bold, Amiri-Regular
│   └── images/ (شعار، أوراق نقدية، أفاتار افتراضي)
├── lib/
│   ├── main.dart                  ← نقطة الدخول: init DB, providers, RTL, theme
│   ├── app.dart                   ← MaterialApp + routes
│   ├── core/                      ← لا يعرف شيئاً عن Flutter UI
│   │   ├── money/                 ← Money, Currency, formatting, Arabic words
│   │   ├── ledger/                ← LedgerService (القواعد R1–R10), errors, balance calc
│   │   ├── db/                    ← AppDatabase, schema.dart, migrations/, DAOs
│   │   ├── sync/                  ← event log export/import, Drive client (مرحلة 5)
│   │   ├── docs/                  ← PDF generators + template engine (مرحلة 4)
│   │   ├── voice/                 ← TTS wrapper, number-to-words
│   │   ├── auth/                  ← PIN hashing, session, permissions
│   │   └── utils/                 ← dates (hijri/gregorian), ids, files (Android/media path)
│   ├── data/
│   │   ├── models/                ← Shop, User, Customer, Transaction, Reminder, DocTemplate…
│   │   └── repositories/          ← CustomerRepo, TransactionRepo… (فوق DAOs، تُستخدم من الـUI)
│   ├── features/                  ← كل مسار من القائمة الجانبية = مجلد
│   │   ├── auth/                  ← user picker, PIN screen
│   │   ├── home/                  ← dashboard + widgets (hero card, recent row…)
│   │   ├── customers/             ← list, detail, add/edit
│   │   ├── transactions/          ← new tx flow (4 steps), list, detail, reverse
│   │   ├── overdue/               ← overdue list, bulk remind
│   │   ├── reports/               ← summaries, aging, top debtors, workers
│   │   ├── documents/             ← document center, template editor, preview
│   │   ├── backup/                ← local/drive backup, export/import
│   │   ├── workers/               ← manage users, activity log
│   │   └── settings/              ← shop, currencies, voice, security, appearance, messages, activation
│   └── shared/
│       ├── theme/                 ← colors (WCAG), typography, ThemeData light/dark
│       └── widgets/               ← AppDrawer, BigButton, MoneyText, CustomerAvatar, AmountChip…
├── test/
│   ├── ledger/                    ← اختبارات القواعد (إجباري 100%)
│   ├── money/
│   └── widgets/
├── android/                       ← package com.sijildebt.ledger
└── web/                           ← للمعاينة فقط
```

**قاعدة الاعتماديات:** `features → data → core`. `core` لا يستورد من `features` أو `data` أبداً. `shared` يُستورد من `features` فقط.

## 2. الطبقات
```
UI (features/*)  ── Provider/ChangeNotifier ──►  Repositories (data/)  ──►  LedgerService + DAOs (core/)  ──►  SQLite
```
- **LedgerService** هو الوحيد الذي يكتب في `transactions`. لا DAO ولا Repo يكتب مباشرة.
- **Repositories** تُرجع نماذج جاهزة للعرض وتخفي SQL.
- **Providers** الفعلية (بعد المرحلة 1): `SessionProvider` (المحل + المستخدم الحالي → `Actor`؛ لا Actor مالك مُثبَّت في الكود أبداً) و`AppServices` (يبني `LedgerService` + `CustomerRepository` + `TransactionsRepository` + `DashboardRepository` بعد معرفة `shopId`). الشاشات تستخدم `FutureBuilder`/`setState` محلياً بدل provider لكل feature — أبسط وكافٍ.
- **`_Gate`** في `app.dart`: لا محل → Onboarding، محل بلا دخول → Login، وإلا الشاشة.
- **`DemoSeed`** خلف `--dart-define=DEMO=true` فقط (`kDemo` في `main.dart`).
- **عملية جديدة** (`features/transactions/new_transaction_flow.dart`): `TxDraft` + Navigator داخلي بأربع خطوات (اختيار زبون → نوع → مبلغ → تأكيد). الحفظ عبر `LedgerService.record` ثم `UndoBar` (8 ث) الذي يعكس عبر `reverse(reason: "تراجع المستخدم")` — لا حذف (R1).
- **الأوراق النقدية** مرسومة بالكود (`widgets/banknote.dart`) لا صور — تكيّف مع أي عملة/شاشة وبلا حقوق صور.
- **الصور** (`shared/services/photo_service.dart`): على Android تُحفظ في documents/photos/*؛ على الويب في الذاكرة (`mem:` prefix) للمعاينة فقط.

## 3. إدارة الحالة
`provider ^6` — بسيط، كافٍ، مفهوم لأي مطوّر. لا Riverpod/Bloc (تعقيد غير مبرَّر هنا).

## 4. التخزين
| ماذا | أين | لماذا |
|---|---|---|
| البيانات | SQLite (`sqflite`) في `getDatabasesPath()` | مستقر، استعلامات، triggers للحماية |
| الصور/الأصوات/PDF/النسخ | `/storage/emulated/0/Android/media/com.sijildebt.ledger/سِجِل/{الصور,الأصوات,المستندات,النسخ_الاحتياطية}` عبر `getExternalStorageDirectories()` | ظاهر للمستخدم مثل واتساب، بلا صلاحيات (Android 10+) |
| نسخة دائمة | `Download/سِجِل/` عند طلب المستخدم (يحتاج `MANAGE_EXTERNAL_STORAGE`? لا — نستخدم MediaStore/SAF عبر `share_plus` أو `file_picker` save) | يبقى بعد إلغاء التثبيت |
| الإعدادات الخفيفة | `shared_preferences` (theme, tts on/off, last user) | |
| السحابة | Google Drive `appDataFolder` — ملف DB مضغوط + `events_<device>.jsonl` | مجلد مخفي، لا يستهلك مساحة المستخدم بشكل ملحوظ، طريقة واتساب |

## 5. المزامنة (مرحلة 5) — التصميم
- كل جهاز له `device_id` ثابت (UUID يُولَّد أول مرة).
- **تصدير:** كل حركة جديدة تُلحَق كسطر JSON في `events_<device_id>.jsonl` محلياً؛ عند الاتصال يُرفع الملف كاملاً (بسيط، صغير: 100 حركة ≈ 30KB).
- **استيراد:** الجهاز يجلب ملفات الأجهزة الأخرى من نفس appDataFolder ويُنفّذ `INSERT OR IGNORE` (R6). يُعيد بناء `balances_cache`.
- **الكيانات القابلة للتعديل** (customers, users, settings): سطر حدث `upsert` بـ`updated_at`؛ الأحدث يفوز؛ القديم يُسجَّل في `audit_log`.
- **الحذف:** غير موجود للحركات؛ الزباين أرشفة (= upsert بـ`is_archived=1`).
- **تجميد جهاز:** المالك يضع `is_frozen=1` في `sync_state` → أحداث ذلك الجهاز بعد التجميد تُهمَل.
- **النسخة الكاملة** (`sijil_backup_YYYY-MM-DD.db.gz`) تُرفع يومياً أيضاً — للاستعادة على جهاز جديد.

## 6. الأمان
- PIN: `sha256(salt + pin)` — 4 أرقام (سهل للعامل)، المالك يمكنه 6.
- بصمة: `local_auth` (مرحلة 2) للمالك.
- قفل تلقائي بعد X دقيقة خمول.
- النسخة المُصدَّرة `.sijil` مشفَّرة AES (مفتاح من عبارة مرور المالك) — مرحلة 5.
- كود التفعيل: `HMAC-SHA256(secret, phone + androidId + plan + expiry)` مُقتطَع لـ16 حرفاً؛ التحقق أوفلاين. السر في الكود مُشوَّش (obfuscated) — الحماية "كافية" لا "مطلقة".

## 7. الحزم وأسباب اختيارها
| الحزمة | الإصدار | السبب |
|---|---|---|
| provider | ^6.1.5 | بسيط ومنتشر |
| sqflite | ^2.4.1 | SQLite Android القياسي |
| sqflite_common_ffi | ^2.3.4 (dev) | اختبارات على سطح المكتب بدون جهاز |
| sqflite_common_ffi_web | ^0.4.5 | تشغيل نفس الكود في معاينة Web |
| uuid | ^4.5.1 | R5 |
| crypto | ^3.0.6 | PIN hash, HMAC |
| pdf + printing | ^3.11 / ^5.13 | مستندات A4 حقيقية، مُختبَر |
| share_plus | ^10.1.4 | مشاركة PDF/نسخة |
| url_launcher | ^6.3.1 | wa.me / sms: |
| flutter_tts | ^4.2.0 | صوت عربي |
| image_picker | ^1.1.2 | صور الزباين/الفواتير |
| google_sign_in + googleapis + extension_… | ^6.2 / ^13.2 / ^2.0 | Drive appDataFolder |
| path_provider, path | | مسارات |
| shared_preferences | ^2.5.3 | إعدادات خفيفة |
| intl | ^0.20.2 | تنسيق تواريخ/أرقام |
| ~~permission_handler~~ | — | **حُذفت في جلسة 4**: لم تُستخدم فعلياً؛ `image_picker` يطلب الكاميرا بنفسه والأذونات مُعلنة في `AndroidManifest.xml`. حذفها قلّص APK. |

**كل هذه حُلَّت بنجاح مع Flutter 3.35.4** (اختُبر بـ`flutter pub get`).

### 7.1 المنصّة المستهدفة: أندرويد فقط (جلسة 4)
- المنتج = APK أندرويد. الويب معاينة تطوير فقط (`DEMO=true`) لأن الساندبوكس بلا محاكي.
- **قبل إضافة أي حزمة:** تحقق أنها تدعم Android، وتُضيف حجماً معقولاً (< 1MB مثالياً). لا داعي لدعم Web/iOS.
- إعدادات الحجم والتوقيع في `android/app/build.gradle.kts` و`proguard-rules.pro` — مفصّلة في `12_RELEASE_GUIDE.md`.
- إن أضفت حزمة بكود Java/Kotlin يُستدعى بالانعكاس (reflection)، أضف قاعدة `-keep` لها في `proguard-rules.pro` وإلا قد تتعطّل في release فقط.

## 8. التسمية والأسلوب
- ملفات `snake_case.dart`، أصناف `PascalCase`، ثوابت `camelCase`.
- كل feature: `<name>_screen.dart`, `<name>_provider.dart`, `widgets/`.
- النصوص العربية الظاهرة: في `lib/shared/l10n/ar_strings.dart` (ثوابت) — لا i18n كامل الآن (لغة واحدة).
- التعليقات بالإنجليزية، مختصرة، تشرح "لماذا" لا "ماذا".
