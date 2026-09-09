# سجل الإصدارات — سِجِل (Sijil)

> **قاعدة:** كل APK يُعطى لأي شخص يجب أن يكون له سطر هنا + وسم Git + GitHub Release.
> الصيغة: `x.y.z+N` — `N` (versionCode) **يزيد دائماً** وإلا يرفض أندرويد التحديث.
> رقم الإصدار يُغيَّر في مكان واحد فقط: `pubspec.yaml` → `version:`. القائمة الجانبية تعرضه من `app_drawer.dart` (حدّثه معه).

## كيف تُصدر نسخة جديدة (خطوات ثابتة)
1. `pubspec.yaml`: ارفع `version: x.y.z+N` (N+1 إلزامي). حدّث النص في `lib/shared/widgets/app_drawer.dart`.
2. `flutter analyze && flutter test` → صفر مشاكل، كل الاختبارات خضراء.
3. `flutter build apk --release --split-per-abi` (تأكد من وجود `android/key.properties` + `release-key.jks` — انظر `docs/12_RELEASE_GUIDE.md §3`).
4. `sha256sum build/app/outputs/flutter-apk/*.apk` — سجّل القيم هنا.
5. أضف قسم الإصدار الجديد أدناه (ما تغيّر، الحجم، SHA-256، commit).
6. `git commit` → `git tag -a sijil-vx.y.z -m "..."` → `git push origin main --tags`.
7. GitHub Release على الوسم + رفع الملفين باسم `sijil-vx.y.z-<abi>.apk` (طريقة REST API موثّقة في `docs/12_RELEASE_GUIDE.md §8`).
8. حدّث `docs/07_PROGRESS.md`.

---

## [0.2.0+2] — 2026-09-09 — أول APK أندرويد موقّع (pre-release للاختبار الميداني)

**تحميل عام (GitHub Release):**
- https://github.com/MoTechSys/Flutter-Native-App-033/releases/tag/sijil-v0.2.0
- arm64-v8a (الهواتف الحديثة): https://github.com/MoTechSys/Flutter-Native-App-033/releases/download/sijil-v0.2.0/sijil-v0.2.0-arm64-v8a.apk — 23.2 MB
- armeabi-v7a (الهواتف القديمة): https://github.com/MoTechSys/Flutter-Native-App-033/releases/download/sijil-v0.2.0/sijil-v0.2.0-armeabi-v7a.apk — 21.3 MB

**SHA-256:**
- arm64-v8a: `d5029efb7fcedf8341487ed94736bb241dc017b59df6da7e2aa34f3301800380`
- armeabi-v7a: `f8bb055befe57fccbd9c622ccf4cb3fe8f5c69a59d0674ebac57f058cd9fc32f`

**Git:** commit `998769f` — وسم `sijil-v0.2.0` — فرع `main`.
**التوقيع:** release key، شهادة SHA-256 تبدأ بـ `9a366b2e` (CN=Flutter App, O=GenSpark). الملفات **داخل المستودع** (`android/key.properties` + `android/release-key.jks`، قرار D17 — المستودع يجب أن يكون خاصاً).
**البيئة:** Flutter 3.35.4 / Dart 3.9.2 / minSdk 21 / targetSdk 36 / package `com.sijildebt.ledger`.
**الاختبارات:** 93 ناجحة، `flutter analyze` صفر.
**الحالة:** مبني ومُختبَر على معاينة الويب فقط — **يلزم اختبار ميداني على هاتف** (`docs/12_RELEASE_GUIDE.md §6`).

### ما يحويه هذا الإصدار (المراحل 0→4)
- المرحلة 0: الأساس + محرك الدفتر (append-only، وحدات صغرى صحيحة، قواعد R1–R10) + الرئيسية (لوحة فقط).
- المرحلة 1: تهيئة المحل + PIN، الزبائن (قائمة/إضافة بصورة/تفاصيل)، عملية جديدة بـ 4 خطوات بالأوراق النقدية + كيبورد + صوت، تراجع، عكس بسبب، سجل العمليات، تذكير واتساب/SMS.
- المرحلة 2: الإعدادات (تسميات أخذ/سدّد، الصوت، الوضع الليلي، حجم الخط، مدة التأخر، تنبيهات)، العملات (YER/YER_OLD/SAR/USD، سعر بالنقر المباشر، كسور دقيقة)، المتأخرون (تقادم، تذكير جماعي، وعد)، التقارير (أسبوع يبدأ السبت)، العمّال + صلاحيات + نشاط، تفعيل HMAC بلا إنترنت + مولّد أكواد.
- المرحلة 3: محرك PDF A4 عربي: 6 أنواع × 3 قوالب + محرر ترويسة/تذييل + حفظ/مشاركة/طباعة + roll80 + علامة ماء التجربة.
- المرحلة 4: نسخ احتياطي `.sijil` (يومي محلي في Android/media + Google Drive)، استعادة آمنة (لا تحذف)، مساعدة صوتية (11 موضوعاً)، زر رجوع 56dp في كل شاشة.
- أندرويد فقط: minify/shrink، proguard، ar/en، تقسيم ABI، حذف `permission_handler`.

### معروف/متعمَّد في هذا الإصدار
- `Activation.secret` ما زال قيمة التطوير — **يجب تغييره قبل أول بيع** (يُبطل أكواد الاختبار، مقصود).
- المزامنة بين جهازين: المحرك جاهز (`importRow`, `sync_state`) بلا واجهة.
- بصمة/`local_auth`، ملاحظة صوتية، `file_picker` للاستيراد: لم تُنفَّذ (قائمة "ما بقي" في `07_PROGRESS.md`).

---

## ما قبل 0.2.0 (بلا APK)
- `2072b44` — المراحل 2–4 (جلسة 3).
- `e847a2e` — المرحلة 1 (جلسة 2).
- `606bc19` / `b13cf69` — المرحلة 0 (جلسة 1–2).
- فرع `kitabi-archive` — مشروع سابق مختلف ("كتابي" v1.0.0/v1.1.0) كان في نفس المستودع؛ محفوظ ولا يُمسّ.
