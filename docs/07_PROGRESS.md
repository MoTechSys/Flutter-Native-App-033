# 07 — سجل التقدّم

> **يُحدَّث كل جلسة.** أعلى الملف = الحالة الآن. الأقدم في الأسفل.
> الصيغة: ✅ منجز • 🔄 جارٍ • ⏳ لم يبدأ • ⚠️ معلَّق/يحتاج قرار

## الحالة الآن (آخر تحديث: الجلسة 1 — 2026-09-09)

**المرحلة الحالية:** 0 — الأساس (Foundation) — **مكتملة تقريباً**
**آخر أمر ناجح:** `flutter build web --release` + معاينة على المنفذ 5060 + لقطة شاشة للرئيسية مطابقة للموك-أب.
**الاختبارات:** `flutter test test/ledger` → **67/67 ناجح** (بعد إصلاح E5).
**`flutter analyze`:** 0 مشاكل.
**Git:** ✅ آخر commit `b13cf69` (الرئيسية مطابقة للتصميم) — قبله `c4cb018`, `ce26ed8` — "Phase 0: foundation, ledger engine (67 tests), full docs, home dashboard". شجرة العمل نظيفة.

### ما أُنجز في المرحلة 0
| البند | الحالة | الملفات |
|---|---|---|
| مشروع Flutter + حزمة `com.sijildebt.ledger` + MainActivity في المسار الصحيح | ✅ | `android/`, `pubspec.yaml` |
| كل الحزم محلولة على Flutter 3.35.4 | ✅ | `pubspec.yaml` |
| الخطوط Tajawal + Amiri | ✅ | `assets/fonts/` |
| التوثيق الكامل (00→09) + الموك-أب + PDF POC + تحليل الإكسل | ✅ | `docs/` |
| `core/money`: Money (int minor)، Currency، MoneyFormat، ArabicWords | ✅ | `lib/core/money/` |
| `core/db`: Schema v1 + triggers R1 + AppDatabase + db_factory (Android/Web) | ✅ | `lib/core/db/` |
| `core/ledger`: LedgerService (record/reverse/balance/statement/recent/cache/integrity/importRow) + errors + models + TxType | ✅ | `lib/core/ledger/` |
| اختبارات: 14 money + 53 ledger = 67 تغطي R1–R10 والحالات #1–#17,#19 جزئياً | ✅ | `test/ledger/` |
| Theme (ألوان WCAG، Tajawal، 56dp) | ✅ | `lib/shared/theme/` |
| AppDrawer (9 بنود + إخفاء للعامل + شارات) | ✅ | `lib/shared/widgets/app_drawer.dart` |
| HomeScreen مطابق لـ `01_home_final.png` بلا تمرير + صف أفقي للحركات — **مُدقَّق بصرياً** (`design/preview_home_phase0.png`) | ✅ | `lib/features/home/` |
| DashboardRepository (إجمالي، اليوم، متأخرين، آخر الحركات) | ✅ | `lib/data/repositories/` |
| DemoSeed (10 زباين، 21 حركة) للمعاينة فقط | ✅ | `lib/data/demo/` |
| Routes + ComingSoon لكل مسار غير مبني | ✅ | `lib/app.dart`, `lib/app_routes.dart` |
| بناء Web + خادم + لقطة شاشة | ✅ | `build/web/` |

### ما بقي من المرحلة 0
- [x] Git commit أولي ✅ `ce26ed8`
- [x] أيقونة التطبيق ✅ (`assets/icon/app_icon.png` + mipmaps Android + `web/icons/*` + favicon)
- [x] تدقيق فني/تصميمي للمرحلة 0 ✅ `10_AUDIT_PHASE0.md` — الحكم: **مقبولة**، وطُبِّقت التصحيحات الأربعة:
  - `recent(liveOnly:true)` فلترة العكسيات في SQL (+ اختبار → 68/68)
  - هدف لمس ☰ = 56dp
  - سهم ↗/↘ داخل شريحة المبلغ في صف آخر الحركات
  - الأيقونة
- [x] لقطة القائمة الجانبية ✅ `design/preview_drawer_phase0.png`
- [x] تراكب صور المتأخرين ✅
- [ ] اختبار `verifyIntegrity()` بعد استيراد من جهاز ثانٍ (حالة #9 بعمق أكبر)

### قرارات جديدة من التدقيق (مضافة إلى `01_CONTEXT.md`)
- **D11** تسميات "أخذ/سدّد" قابلة للتعديل من الإعدادات (لهجات مختلفة).
- **D12** رئيسية العامل تختلف عن رئيسية المالك (المرحلة 5): بلا إجماليات، فقط زباين + عملية جديدة.
- **D13** اختبار ميداني مع 3 عمال حقيقيين قبل إعلان اكتمال المرحلة 1.

### ملاحظات للجلسة التالية
1. اقرأ `00_START_HERE.md` ثم هذا الملف. تأكد `git status` نظيف.
2. أعد البناء: `flutter build web --release` وشغّل الخادم (الأمر في `00_START_HERE.md`) وخذ لقطة للقائمة الجانبية.
3. بعدها ابدأ **المرحلة 1** من `06_PLAN.md` بالترتيب: دخول المستخدم → الزباين → عملية جديدة (4 خطوات) → الحركات.
4. عند بناء الزباين/الحركات: استبدل `DemoSeed` بـ onboarding حقيقي، لكن أبقِ DemoSeed خلف علم `--dart-define=DEMO=true` للمعاينة.
5. `sqflite_common_ffi_web:setup` أنشأ `web/sqflite_sw.js` و`web/sqlite3.wasm` — **لا تحذفهما** (المعاينة تعتمد عليهما).

### قاعدة عمل جديدة (بعد E6)
**كل شاشة تُسلَّم مع لقطة فعلية (`shot.py`) مقارنة بالموك-أب عنصراً عنصراً.** بدون ذلك الشاشة غير مكتملة.

### قرارات تقنية اتُّخذت أثناء التنفيذ (مضافة للتوثيق)
- ترتيب الحركات بـ `rowid` لا `id` (E5).
- `balance()` يستثني **طرفَي** القيد العكسي (الأصل والعكس) — النتيجة نفسها لكن `tx_count` يعكس الحركات "الحيّة" فقط.
- المزامنة: `LedgerService.importRow()` جاهزة بـ `INSERT OR IGNORE` (R6) — تُستخدم في المرحلة 4.
- `Actor` يُمرَّر لكل عملية (لا حالة عامة للمستخدم داخل `core`) → قابل للاختبار.
- Web preview يستخدم `sqflite_common_ffi_web` (نفس الكود، sql.js). Android يستخدم `sqflite`.

## سجل الجلسات
### الجلسة 1 — 2026-09-09
- تحليل ملف Excel القديم للعميل (VBA + الصيغ) → `research/`.
- اختيار الفكرة بعد بحث السوق → دفتر ديون "سِجِل".
- بحث: الأمية، الإنترنت، AdMob، المنافسون، تصميم للأمي، هندسة الدفاتر، المزامنة، PDF عربي (مع POC فعلي).
- 3 جولات تصميم → اعتماد B مُعدَّل + drawer + transactions list.
- كتابة التوثيق الكامل.
- بناء الأساس + محرك الحسابات + 67 اختبار (كشف خطأ ترتيب حقيقي E5 وأُصلح).
- الرئيسية تعمل في المعاينة ومطابقة للتصميم.

### الجلسة 2 — 2026-09-09 (تكملة)
- إصلاح بصري بعد رفض العميل (E6) → لقطة مطابقة للموك-أب.
- تدقيق فني+تصميمي شامل مقابل البحوث (`10_AUDIT_PHASE0.md`) → مقبول + 4 تصحيحات نُفِّذت.
- الأيقونة مُدمجة. 68/68 اختبار. `flutter analyze` صفر.
- **المرحلة 0 مكتملة** → بدء المرحلة 1.
