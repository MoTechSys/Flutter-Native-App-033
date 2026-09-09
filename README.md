# سِجِل (Sijil) — دفتر ديون رقمي للمحلات اليمنية

> **Android فقط.** أوفلاين أولاً. للمالك والعامل (حتى الأمي). حسابات دين بلا خطأ.
> **ابدأ من هنا:** [`docs/00_START_HERE.md`](docs/00_START_HERE.md) → [`docs/13_NEW_AGENT_BOOTSTRAP.md`](docs/13_NEW_AGENT_BOOTSTRAP.md) (وكيل جديد: خطوات البيئة المُجرَّبة + أسلوب العميل) → [`docs/07_PROGRESS.md`](docs/07_PROGRESS.md) لتعرف ما تم وما بقي.

| | |
|---|---|
| الحزمة | `com.sijildebt.ledger` |
| Flutter / Dart | 3.35.4 / 3.9.2 (مثبّتة — لا تُحدَّث) |
| الإصدار | `0.2.0+2` |
| الاختبارات | `flutter test` → 93/93 |
| التحليل | `flutter analyze` → 0 |
| مستودع GitHub | https://github.com/MoTechSys/Flutter-Native-App-033 (فرع `main`) |
| سجل الإصدارات | [`CHANGELOG.md`](CHANGELOG.md) — **المرجع الوحيد** لأرقام الإصدارات وروابط APK |

## تحميل التطبيق (رابط عام دائم)
آخر إصدار: **v0.2.0 (build 2)** — https://github.com/MoTechSys/Flutter-Native-App-033/releases/tag/sijil-v0.2.0

| الملف | لمن | الحجم |
|---|---|---|
| [sijil-v0.2.0-arm64-v8a.apk](https://github.com/MoTechSys/Flutter-Native-App-033/releases/download/sijil-v0.2.0/sijil-v0.2.0-arm64-v8a.apk) | الهواتف الحديثة — **ابدأ به** | 23.2 MB |
| [sijil-v0.2.0-armeabi-v7a.apk](https://github.com/MoTechSys/Flutter-Native-App-033/releases/download/sijil-v0.2.0/sijil-v0.2.0-armeabi-v7a.apk) | الهواتف القديمة الرخيصة | 21.3 MB |

كل الإصدارات: https://github.com/MoTechSys/Flutter-Native-App-033/releases

## ماذا يفعل التطبيق
- **الرئيسية** لوحة تحكم: إجمالي "لك عند الناس"، المتأخرون، اليوم، 4 اختصارات، صف آخر الحركات (صور).
- **عملية جديدة في 4 خطوات**: زبون (صورة) → أخذ/دفع (زرّان عملاقان) → المبلغ **بالأوراق النقدية** أو لوحة أرقام → تأكيد بقراءة صوتية. تراجع 8 ثوانٍ.
- **الزباين**: شبكة/قائمة، صور، فلاتر، صفحة زبون برصيد ضخم + واتساب/رسالة/كشف.
- **الحركات**: قائمة بتواريخ، تفاصيل، عكس (للمالك بسبب — لا حذف أبداً).
- **المتأخرين**: تقادم 30/60/90/180، ذكّر الكل، وعد بالدفع.
- **التقارير**: يوم/أسبوع/شهر/سنة، أعلى 10، أداء العمال.
- **المستندات PDF** (A4 حقيقية): كشف مختصر/تفصيلي، سند قبض (A5/حراري 80mm)، إشعار مطالبة، تقرير المتأخرين، إقرار بالدين — 3 قوالب + محرر ترويسة/تذييل بمعاينة حية.
- **العملات**: ريال يمني (جديد/قديم)، سعودي، دولار — كل عملة دفتر مستقل؛ الضغط على السعر يفتح الكيبورد مباشرة.
- **العمال**: حسابات بصور + PIN + صلاحيات + سجل نشاط. **الإعدادات**: كلمات أخذ/دفع قابلة للتعديل، صوت، داكن، خط، قفل فترة…
- **النسخ**: يومي محلي في `Android/media/com.sijildebt.ledger/سِجِل/`، ملف `.sijil` مُتحقَّق، Google Drive.
- **التفعيل**: كود أوفلاين مرتبط بالجهاز (`tool/gen_activation.dart`)، تجربة 30 يوماً.
- **مساعدة صوتية**: 11 موضوعاً بخطوات مرقّمة.

## البناء (Android)
```bash
flutter pub get
flutter analyze && flutter test
flutter build apk --release --split-per-abi
# → build/app/outputs/flutter-apk/app-arm64-v8a-release.apk   (~23 MB — الهواتف الحديثة)
# → build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk (~21 MB — الهواتف القديمة الرخيصة)
```
- التوقيع: `android/key.properties` + `android/release-key.jks` (**غير مرفوعة للمستودع** — احتفظ بنسخة آمنة؛ ضياعها = لا تحديثات لنفس التوقيع).
- الحجم: `minifyEnabled` + `shrinkResources` + split per ABI + خطوط مضمّنة فقط. لا تُضف حزماً لا تحتاجها.
- المعاينة على الويب للتطوير فقط: `flutter build web --release --dart-define=DEMO=true` ثم خادم على 5060 (انظر `docs/00_START_HERE.md`).

## بنية الكود (مختصر — التفاصيل في `docs/05_ARCHITECTURE.md`)
```
lib/
  core/        ← منطق خالص بلا Flutter UI: money/ ledger/ db/ docs/ activation/
  data/        ← repositories/ session/ backup/ models/ demo/  (+ app_services.dart)
  features/    ← شاشة لكل مجلد: home customers transactions overdue reports documents settings workers backup auth help
  shared/      ← theme/ l10n/ widgets/ services/(speech, photo, reminder) utils/
tool/gen_activation.dart   ← أداة البائع لتوليد أكواد التفعيل
test/                      ← ledger/ (قواعد المحاسبة) data/ (المستودعات، PDF، النسخ، التفعيل)
docs/                      ← ذاكرة المشروع الكاملة (00–11) + لقطات + عينات PDF + بحوث
```

## القواعد التي لا تُخالَف
1. `transactions` **append-only** (Triggers في SQLite). التصحيح = قيد عكسي بسبب.
2. المال **أعداد صحيحة** (`Money(minor)`) — لا `double`. كل عملة دفتر مستقل.
3. `LedgerService` هو الكاتب الوحيد في `transactions`.
4. كل شاشة: زر رجوع صريح، أهداف لمس ≥56dp، لا اعتماد على اللون وحده، بلا تمرير طويل.
5. كل شاشة تُسلَّم مع لقطة فعلية مقارنة بالموك-أب (`docs/design/`).
6. لا `print()`, لا `withOpacity()`, لا `!` بلا تحقق. `flutter analyze` = 0 دائماً.
