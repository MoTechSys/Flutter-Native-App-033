# دليل البناء — كِتابي (Kitabi Bookstore)

> هذا الملف لأي شخص يحمّل المستودع ويريد **تشغيل التطبيق أو إنتاج ملف APK بنفسه** خطوة بخطوة.
> آخر APK جاهز موجود في مجلد [`releases/`](releases/) — إن أردت التثبيت فقط بلا بناء، حمّله من هناك.

---

## 0. ما الموجود في المستودع؟

| المسار | الغرض |
|---|---|
| `releases/Kitabi-v1.1.0.apk` | **آخر إصدار جاهز للتثبيت** (موقّع، android-arm64) |
| `lib/` | كود التطبيق (Dart) |
| `test/` | 31 اختباراً آلياً (`flutter test`) |
| `assets/covers/` , `assets/brand/` | أغلفة الكتب (24) + الشعار |
| `android/` | مشروع أندرويد (الحزمة `com.kitabibookstore.books`) |
| `web/` | ملفات الويب (تشمل `sqlite3.wasm` و`sqflite_sw.js` لعمل SQLite في المتصفح) |
| `license.json` | **ملف التحكم عن بُعد** — يقرأه التطبيق عند كل تشغيل (انظر §6) |
| `docs/ARCHITECTURE.md` | الوثيقة المعمارية الكاملة |
| `docs/RELEASE_NOTES.md` | ملاحظات الإصدارات |
| `docs/SESSION_LOG.md` | سجل التطوير: القرارات والتخطيط والمشاكل وحلولها |
| `docs/make_assets.py` | سكربت توليد الأغلفة والأيقونات (Pillow) |

---

## 1. المتطلبات (الإصدارات التي بُني بها المشروع)

| الأداة | الإصدار | ملاحظة |
|---|---|---|
| Flutter | **3.35.4** (قناة stable) | أي 3.35.x يعمل. لا تستخدم أقدم من 3.27 (يستخدم `PopScope.onPopInvokedWithResult` و`switch` النمطي) |
| Dart | 3.9.2 | يأتي مع Flutter |
| Java (JDK) | **17** | لا تستخدم 21؛ Gradle مضبوط على 17 |
| Android SDK | compileSdk 36 / minSdk 21 / Build-Tools 35.0.0 | يُثبَّت من Android Studio → SDK Manager |
| Git | أي إصدار | |

تحقق:
```bash
flutter --version      # Flutter 3.35.x • Dart 3.9.x
java -version          # openjdk 17
flutter doctor         # يجب أن يظهر ✓ أمام Android toolchain
```

---

## 2. تحميل المشروع وتشغيله (تطوير)

```bash
git clone https://github.com/MoTechSys/Flutter-Native-App-033.git
cd Flutter-Native-App-033
flutter pub get
flutter analyze            # يجب: No issues found!
flutter test               # يجب: All tests passed! (31)
flutter run                # على جهاز/محاكي أندرويد متصل
```

للويب (للمعاينة فقط):
```bash
flutter run -d chrome
```

---

## 3. بناء APK

### 3.أ — APK بمفتاح التوقيع الأصلي (نفس مفتاح الإصدارات المنشورة)
يلزمك ملفان **غير مضمّنين في المستودع** (لأسباب أمنية، مذكوران في `.gitignore`):

```
android/release-key.jks     ← مخزن المفاتيح
android/key.properties      ← كلمات السر والاسم المستعار
```

شكل `android/key.properties`:
```properties
storePassword=********
keyPassword=********
keyAlias=release
storeFile=../release-key.jks
```
> اطلب الملفين من صاحب المشروع. **يجب استخدام نفس المفتاح** لتثبيت تحديث فوق نسخة مثبّتة سابقاً؛ مفتاح مختلف = أندرويد يرفض التحديث ويطلب حذف التطبيق أولاً.

ثم:
```bash
flutter build apk --release --target-platform android-arm64
# النتيجة: build/app/outputs/flutter-apk/app-release.apk  (~20 MB)
```
لملف يعمل على كل المعالجات (أكبر حجماً ~50 MB):
```bash
flutter build apk --release
```
أو ملف لكل معمارية:
```bash
flutter build apk --release --split-per-abi
```

### 3.ب — ليس لديك مفتاح التوقيع؟ أنشئ مفتاحاً جديداً
```bash
keytool -genkey -v -keystore android/release-key.jks -keyalg RSA -keysize 2048 \
        -validity 10000 -alias release
```
ثم أنشئ `android/key.properties` بالشكل أعلاه. (النسخة الناتجة **لا** تُحدِّث نسخة مثبّتة بالمفتاح الأصلي.)

### 3.ج — بلا أي توقيع (للتجربة فقط)
```bash
flutter build apk --debug
```

### التحقق من الـ APK
```bash
$ANDROID_HOME/build-tools/35.0.0/apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
$ANDROID_HOME/build-tools/35.0.0/aapt dump badging build/app/outputs/flutter-apk/app-release.apk | grep ^package
# package: name='com.kitabibookstore.books' versionCode='2' versionName='1.1.0'
```

### التثبيت على جهاز متصل بالكيبل
```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

---

## 4. إصدار نسخة جديدة (Checklist)

1. عدّل الكود.
2. ارفع الرقم في `pubspec.yaml`: `version: 1.2.0+3` (الرقم بعد `+` هو `versionCode` **ويجب أن يزيد** في كل إصدار وإلا يرفض أندرويد التحديث).
3. حدّث `appVersion` في `lib/ui/profile/about_page.dart`.
4. `flutter analyze && flutter test`.
5. `flutter build apk --release --target-platform android-arm64`.
6. انسخ الناتج إلى `releases/Kitabi-vX.Y.Z.apk` واحذف القديم إن أردت.
7. أضف بنداً في `docs/RELEASE_NOTES.md`.
8. `git add -A && git commit -m "vX.Y.Z: ..." && git tag vX.Y.Z && git push origin main --tags`.

---

## 5. الأخطاء الشائعة وحلولها

| الخطأ | السبب | الحل |
|---|---|---|
| `Keystore file not found` / `key.properties (No such file)` | ملفا التوقيع غير موجودين | §3.أ أو §3.ب |
| `Unsupported class file major version` / Gradle يفشل عند البداية | JDK 21 بدل 17 | ثبّت JDK 17 واضبط `JAVA_HOME` |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` عند التثبيت | مفتاح توقيع مختلف عن النسخة المثبّتة | احذف التطبيق القديم أو استخدم المفتاح الأصلي |
| `INSTALL_FAILED_VERSION_DOWNGRADE` | `versionCode` أقل أو يساوي المثبّت | ارفع الرقم بعد `+` في `pubspec.yaml` |
| التطبيق يفتح على شاشة "موقوفة نهائياً" | `license.json` غير موجود على GitHub (404) | تأكد من وجود الملف في جذر فرع `main` (§6) |
| شاشة بيضاء على الويب / خطأ SQLite | `web/sqlite3.wasm` أو `web/sqflite_sw.js` مفقودان | موجودان في المستودع؛ لا تحذفهما |
| `flutter pub get` يفشل | لا إنترنت أو إصدار Flutter قديم | حدّث Flutter إلى 3.35.x |
| `Execution failed for task ':app:lintVitalAnalyzeRelease'` | تحذيرات lint | `flutter build apk --release --no-tree-shake-icons` أو أضف `lint { checkReleaseBuilds = false }` في `android/app/build.gradle.kts` |

---

## 6. التحكم عن بُعد (`license.json`) — كيف يعمل وكيف تستخدمه

التطبيق يقرأ `https://github.com/MoTechSys/Flutter-Native-App-033/blob/main/license.json` عند كل تشغيل (عبر GitHub API أولاً ثم الملف الخام كاحتياط).

```json
{
  "active": true,
  "code": "KTB-2025",
  "message": "رسالة تظهر للمستخدم عند القفل"
}
```

| تريد | افعل | ماذا يرى المستخدم |
|---|---|---|
| تشغيل عادي | `"active": true` | يدخل مباشرة |
| إيقاف مع إمكانية الفتح بكود | `"active": false` + ضع `code` | شاشة قفل تطلب الكود؛ بعد إدخاله صحيحاً يُحفظ ويفتح تلقائياً في المرات القادمة **ما لم تغيّر الكود** |
| إيقاف نهائي | **احذف الملف** من المستودع | "النسخة موقوفة نهائياً" — لا يقبل أي كود |
| بلا إنترنت | — | يعمل بآخر حالة رآها |

التعديل يصل خلال ثوانٍ (لا كاش CDN). كل هذا في `lib/security/access_control.dart` ومغطّى باختبارات `test/security_test.dart`.

---

## 7. حسابات التجربة

لا توجد حسابات مسبقة — أنشئ حساباً من شاشة التسجيل واختر النوع:
- **مستخدم**: تسوّق، سلة، مفضلة، طلبات، مراجعات.
- **مدير المتجر**: كل ما سبق + لوحة "إدارة المتجر" من صفحة حسابي (إضافة/تعديل/حذف كتب وتصنيفات + إحصاءات).

كوبونات الخصم الفعّالة: `KITABI10` · `READ20` · `WELCOME15`.

قاعدة البيانات تُنشأ تلقائياً عند أول تشغيل في `/data/data/com.kitabibookstore.books/databases/kitabi.db` مع 24 كتاباً حقيقياً و6 تصنيفات.
