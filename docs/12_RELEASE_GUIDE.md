# 12 — دليل الإصدار (أندرويد فقط)

> اقرأ هذا قبل إعطاء التطبيق لأي زبون. آخر تحديث: جلسة 4 — v0.2.0+2.

## 1. القرار: أندرويد فقط، حجم صغير
العميل طلب صراحةً: "فقط تطبيق أندرويد، لا أريد تطبيقاً حجمه كبير". لذلك:

| الإعداد | القيمة | أين | لماذا |
|---|---|---|---|
| `minSdk` | 21 (Android 5.0) | `android/app/build.gradle.kts` | يغطي الهواتف الرخيصة في اليمن |
| `resourceConfigurations` | `ar`, `en` | نفس الملف | يحذف ترجمات AndroidX لعشرات اللغات |
| `isMinifyEnabled` / `isShrinkResources` | true | نفس الملف | تقليص كود Java/Kotlin والموارد |
| `proguard-rules.pro` | keep لـ flutter / sqflite / printing / flutter_tts / gms | `android/app/` | حتى لا يكسر التقليص الإضافات |
| تقسيم ABI | arm64-v8a + armeabi-v7a، بلا universal | نفس الملف | نصف حجم APK الشامل |
| الأصول | `assets/icon/` فقط؛ الأوراق النقدية ترسم بالكود | `pubspec.yaml` | لا صور كبيرة داخل APK |
| حزم محذوفة | `permission_handler` | `pubspec.yaml` | لم تكن مستخدمة فعلياً؛ الأذونات تُعلن في Manifest |

**النتيجة الحالية:** arm64 = 23.2 MB، armv7 = 21.3 MB.
معظم الحجم = محرّك Flutter (~7MB) + خط عربي مضمّن للـ PDF + مكتبات pdf/printing/sqflite/tts. لا يمكن النزول كثيراً دون حذف ميزات.

## 2. البناء
```bash
cd /home/user/flutter_app
flutter pub get && flutter analyze && flutter test
flutter build apk --release --split-per-abi
ls -la build/app/outputs/flutter-apk/
```
- **رسالة زائفة معروفة:** بعد نجاح البناء وطباعة مساري الملفين، قد يطبع Flutter
  `Gradle build failed to produce an .apk file` — سببها أنه يبحث عن APK شامل ونحن عطّلناه. تجاهلها إن كان الملفان موجودين.
- أي زبون: أعطه `app-arm64-v8a-release.apk`. إن فشل التثبيت (هاتف قديم جداً) أعطه `armeabi-v7a`.
- لنشر Google Play مستقبلاً: `flutter build appbundle --release` (يحتاج نفس التوقيع).

## 3. التوقيع — الأهم
- الملفات: `android/key.properties` + `android/release-key.jks` (أُنشئتا في جلسة 4 عبر `flutter_signing_tool`).
- **داخل Git عمداً (قرار العميل D17، جلسة 4):** "حتى التوقيع، كل شيء يرفعه في المستودع" — حتى لا يضطر لتذكّر روابط نسخ احتياطية. أي وكيل يستنسخ المستودع يبني APK قابلاً للتحديث فوراً.
- **الشرط المقابل: المستودع يجب أن يكون خاصاً (Private).** بمستودع عام، أي شخص يقدر يوقّع تطبيقاً مزيفاً باسم سِجِل ويحدّث تطبيق الزبائن. تحويله لخاص من: GitHub → Settings → Danger Zone → Change visibility (التوكن الآلي لا يملك هذه الصلاحية — يفعلها العميل بيده). ملاحظة: بعد التحويل تصبح روابط Releases خاصة أيضاً؛ رابط التحميل العام للزبائن يُنشر عبر بديل (انظر §9).
- **لا تغيّر المفتاح أبداً.** إن أنشأت مفتاحاً جديداً فلن يقبل أندرويد التحديث فوق النسخة المثبّتة؛ الزبائن سيحتاجون حذفاً وإعادة تثبيت (**وضياع بياناتهم إن لم يأخذوا نسخة `.sijil`**).
- إن غابت الملفات (مستودع منسوخ بلا `android/`)، البناء يوقّع بمفتاح debug — يعمل للاختبار، **لا للتوزيع**.
- تحقق من التوقيع:
  ```bash
  ~/android-sdk/build-tools/35.0.0/apksigner verify --print-certs build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
  ```
  بصمة الشهادة الحالية SHA-256 تبدأ بـ `9a366b2e` (CN=Flutter App, O=GenSpark).

## 4. قبل أول إصدار تجاري — قائمة إلزامية
- [ ] **غيّر `Activation.secret`** في `lib/core/activation/activation.dart` إلى سر عشوائي طويل، ولا تنشره. أكواد التفعيل المولّدة بالسر القديم تصبح باطلة (مقصود).
- [ ] احتفظ بنفس السر في `tool/gen_activation.dart` (يقرأ من الكلاس نفسه — لا ازدواج).
- [ ] ارفع `version` في `pubspec.yaml` (`x.y.z+N` — N يجب أن يزيد كل إصدار وإلا يرفض أندرويد التحديث).
- [ ] `flutter test` كلها خضراء + `flutter analyze` بلا مشاكل.
- [ ] اختبر النسخ الاحتياطي والاستعادة على جهاز حقيقي (ملف `.sijil` في `Android/media/com.sijildebt.ledger/سِجِل/`).
- [ ] اختبر PDF على جهاز حقيقي (الطباعة/المشاركة عبر `printing`).
- [ ] اختبر الصوت (flutter_tts) — بعض الهواتف الرخيصة بلا محرّك عربي؛ التطبيق يجب أن يعمل بصمت دون تعطّل.

## 5. أكواد التفعيل (بيع)
```bash
# الزبون يفتح: الإعدادات → التفعيل → يقرأ لك "رقم الجهاز"
dart run tool/gen_activation.dart <deviceId> Y1      # سنة
dart run tool/gen_activation.dart <deviceId> Y3      # 3 سنوات
dart run tool/gen_activation.dart <deviceId> LIFE    # مدى الحياة
dart run tool/gen_activation.dart <deviceId> Y1 5    # 5 أكواد مختلفة
```
- الصيغة `SJL-PPPP-EEEE-SSSSSS`، مرتبطة بالجهاز (HMAC-SHA256)، بلا إنترنت.
- تجربة مجانية 30 يوماً من أول تشغيل (`kInstalledAt`)، وعلامة ماء "نسخة تجريبية" على PDF.
- 5 محاولات إدخال خاطئة في الساعة ثم قفل مؤقت.

## 6. اختبار الميدان (D13) — ما لا يُختبر إلا على هاتف
هذه البنود بُنيت ولم تُشغَّل على أندرويد حقيقي لأن الساندبوكس بلا محاكي. **يلزم تجربتها قبل التوزيع:**

| البند | كيف تختبره | المتوقع |
|---|---|---|
| الكاميرا (صورة الزبون) | إضافة زبون → أيقونة الكاميرا | تفتح الكاميرا، الصورة تُحفظ داخل التطبيق وتظهر في القائمة |
| الصوت | الإعدادات → المساعدة الصوتية مفعّلة → افتح أي شاشة | يقرأ العناوين بالعربية؛ إن لم يوجد محرّك عربي: صمت بلا تعطّل |
| واتساب/SMS | تفاصيل زبون → تذكير | يفتح واتساب برسالة معبّأة؛ إن لم يوجد واتساب يفتح SMS |
| PDF | المستندات → أي مستند → مشاركة/طباعة | ملف A4 عربي صحيح الاتجاه، ويُحفظ في `Android/media/.../سِجِل/المستندات/` |
| النسخ المحلي | يعمل تلقائياً يومياً + زر يدوي | ملف `.sijil` يظهر في مدير الملفات |
| Google Drive | النسخ الاحتياطي → ربط Drive | يطلب حساب Google ثم يرفع النسخة |
| الوضع الليلي وحجم الخط | الإعدادات | يتغيّر فوراً دون إعادة تشغيل |
| 3 عمّال + مالك | المستخدمون → أضف عاملاً + PIN + صلاحيات | العامل بلا `see_totals` يرى `_WorkerHero` فقط (بلا أرقام إجمالية) |
| قفل تلقائي | الإعدادات → دقائق القفل | يعود لشاشة PIN بعد المدة |

سجّل أي خلل في `08_ERRORS_AND_LESSONS.md` بنفس الصيغة (E12، E13، …).

## 7. ما لا تفعله أبداً في الإصدار
- لا تُعِد تفعيل APK شامل (`isUniversalApk = true`) — يضاعف الحجم.
- لا تُضف حزمة دون التحقق أنها تعمل على أندرويد وحجمها معقول (راجع `05_ARCHITECTURE.md`).
- لا تغيّر `applicationId` (`com.sijildebt.ledger`) — يُعتبر تطبيقاً مختلفاً عند الزبائن.
- لا تلمس جداول الدفتر إلا عبر `LedgerService` (القواعد R1–R10 في `04_LEDGER_RULES.md`).
- لا تحدّث Flutter/Dart (مثبّتان على 3.35.4 / 3.9.2).

## 8. نشر APK كرابط عام دائم (GitHub Release)
الرابط من الساندبوكس يموت بانتهاء الجلسة. الرابط الدائم = GitHub Release على الوسم. لا يوجد `gh` في الساندبوكس، فنستخدم REST API بالتوكن الذي يضعه `setup_github_environment` في `~/.git-credentials`:

```bash
cd /home/user/flutter_app
V=0.2.0                                # نفس رقم pubspec بدون +N
TOKEN=$(grep -o 'https://[^@]*@github.com' ~/.git-credentials | head -1 | sed 's#https://##;s#@github.com##' | cut -d: -f2)
REPO=MoTechSys/Flutter-Native-App-033

# 1) الوسم (إن لم يكن موجوداً)
git tag -a sijil-v$V -m "Sijil v$V" && git push origin --tags

# 2) إنشاء الإصدار (prerelease=true حتى ينتهي الاختبار الميداني)
RID=$(curl -s -X POST -H "Authorization: token $TOKEN" https://api.github.com/repos/$REPO/releases \
  -d "{\"tag_name\":\"sijil-v$V\",\"name\":\"سِجِل v$V\",\"body\":\"انظر CHANGELOG.md\",\"prerelease\":true}" | python3 -c "import json,sys;print(json.load(sys.stdin)['id'])")

# 3) رفع الملفين بأسماء واضحة
for ABI in arm64-v8a armeabi-v7a; do
  curl -s -X POST -H "Authorization: token $TOKEN" -H "Content-Type: application/vnd.android.package-archive" \
    --data-binary @build/app/outputs/flutter-apk/app-$ABI-release.apk \
    "https://uploads.github.com/repos/$REPO/releases/$RID/assets?name=sijil-v$V-$ABI.apk" > /dev/null
done

# 4) تحقق أن الرابط عام (يجب 200 بلا توكن)
curl -sIL https://github.com/$REPO/releases/download/sijil-v$V/sijil-v$V-arm64-v8a.apk | grep HTTP | tail -1
```
- صيغة الرابط المباشر الثابتة: `https://github.com/MoTechSys/Flutter-Native-App-033/releases/download/sijil-v<V>/sijil-v<V>-<abi>.apk`
- سجّل الروابط + SHA-256 في `CHANGELOG.md` (جذر المشروع). هو **المرجع الوحيد** لأرقام الإصدارات.
- عند اعتماد الإصدار بعد الميدان: عدّل الإصدار `prerelease:false` من صفحة GitHub.

## 9. رابط تحميل عام للزبائن إن صار المستودع خاصاً
عندما يتحوّل المستودع إلى Private، روابط `releases/download/...` تطلب تسجيل دخول. البدائل (اختر واحداً ووثّقه في `CHANGELOG.md`):
1. **مستودع ثانٍ عام للتوزيع فقط** (مثلاً `MoTechSys/sijil-releases`) لا يحوي إلا ملفات APK في Releases — الأسهل والأدوم. نفس أوامر §8 مع تغيير `REPO`.
2. Google Drive للعميل (رابط "أي شخص لديه الرابط") — يدوي لكن بسيط.
3. رابط الساندبوكس (`flutter_build_completion_notifier`) — **مؤقت**، يموت مع الجلسة؛ للاختبار الفوري فقط.
