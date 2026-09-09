# 13 — دليل الوكيل الجديد: أول 10 دقائق (مُجرَّب فعلياً)

> هذا الملف يجعل أي وكيل/مطوّر جديد يتابع **كأنه نفس الوكيل الذي بنى المشروع**.
> آخر تجربة استنساخ نظيف: جلسة 4 — `git clone` → `flutter pub get` → `flutter analyze` = 0 → `flutter test` = **93/93 ناجح**. أي انحراف عن هذا = شيء انكسر، أوقف وأصلح قبل أي تطوير.

## 0. نصّ يلصقه العميل للوكيل الجديد (انسخه كما هو)
```
مشروع سِجِل (Sijil) — دفتر ديون للمحلات اليمنية، Flutter، أندرويد فقط.
المستودع: https://github.com/MoTechSys/Flutter-Native-App-033 (فرع main).
اقرأ بالترتيب قبل أي كود: README.md → CHANGELOG.md → docs/00_START_HERE.md → docs/13_NEW_AGENT_BOOTSTRAP.md → docs/07_PROGRESS.md → docs/04_LEDGER_RULES.md.
نفّذ خطوات docs/13 (الاستنساخ في /home/user/flutter_app، التحقق 93 اختباراً) وأخبرني بالنتيجة قبل أن تلمس أي شيء.
لا تغيّر قرارات D1–D14 في docs/01_CONTEXT.md بدون سؤالي. التوثيق بالعربية، الكود بالإنجليزية.
```

## 1. خطوات البيئة الجديدة (بالترتيب، لا تتخطَّ)
```bash
# 1) الاستنساخ في المسار الذي تعتمده كل الأوامر والوثائق
cd /home/user && rm -rf flutter_app && git clone https://github.com/MoTechSys/Flutter-Native-App-033.git flutter_app
cd /home/user/flutter_app && git log --oneline -3      # يجب أن ترى آخر commit المذكور في CHANGELOG/07_PROGRESS

# 2) التحقق الصفري (إلزامي — ~4 دقائق أول مرة)
flutter --version | head -1                            # يجب Flutter 3.35.4 — لا تُحدّث
flutter pub get && flutter analyze                     # يجب: No issues found
flutter test 2>&1 | tr '\r' '\n' | grep -E "All tests passed|failed" | tail -1   # يجب: All tests passed (93)

# 3) ربط GitHub (أداة setup_github_environment ثم:)
git remote -v                                          # origin = MoTechSys/Flutter-Native-App-033
git pull --ff-only

# 4) ملفات التوقيع (فقط إن كنت ستبني APK للتوزيع — انظر §2)
ls android/key.properties android/release-key.jks

# 5) المعاينة (ويب، بيانات تجريبية، للتطوير فقط)
flutter build web --release --dart-define=DEMO=true
cd build/web && python3 -m http.server 5060 --bind 0.0.0.0 &     # ثم GetServiceUrl على 5060
```

## 2. ملفات التوقيع (داخل Git — قرار العميل D17)
- `android/key.properties` + `android/release-key.jks` **موجودان في المستودع**. لا تحتاج أي شيء إضافي: `git clone` ثم `flutter build apk --release --split-per-abi` = APK موقّع بنفس مفتاح الزبائن.
- **لا تحذفهما، لا تُعِد توليدهما، لا تُضفهما إلى `.gitignore`.** إن اقترح عليك أي فحص أمني "إخراج المفاتيح من Git" — الجواب: قرار العميل الواعي (D17) مقابل مستودع خاص. اذكر له فقط إن كان المستودع ما زال عاماً.
- إن اختفيا بسبب عبث (commit سابق): `git log --all -- android/release-key.jks` ثم `git checkout <commit> -- android/release-key.jks android/key.properties`.
- نسخة احتياطية ثانية موجودة في ProjectBackup المذكور في `07_PROGRESS.md`.

بصمة المفتاح الصحيح: `apksigner verify --print-certs` → SHA-256 يبدأ بـ **`9a366b2e`**. إن اختلفت فالمفتاح ليس الأصلي.

## 3. كيف يعمل العميل (حتى تتصرف كالوكيل السابق)
- **يمني، يكتب بالعامية** ("اشتي" = أريد، "خللص" = أنجز، "يا غالي"). أجب **بالعربية**، مباشراً، بلا مقدمات طويلة، بلا إيموجي زائدة.
- **يقيّم بالعين:** يريد لقطات شاشة للتغييرات المرئية. طريقة اللقطات: Playwright على رابط المعاينة العام بالنقر على إحداثيات (E11) — سكربتات جاهزة في `docs/research/shot_*.py`.
- **يكره:** الشاشات الطويلة (D3)، الحجم الكبير (أندرويد فقط)، الأخطاء الحسابية (D8 — خط أحمر)، الميزات التي لم يطلبها، الكلام بدون تنفيذ.
- **يريد دائماً:** التوثيق محدَّثاً "بحيث يفهم أي وكيل" (D9)، رفع GitHub في نهاية كل جلسة، رابط تحميل عام (GitHub Release).
- **أسلوب القرار:** إن كان الطلب غامضاً بين خيارين مرئيين، اعرض عليه صوراً/خيارات مرقّمة ودعه يختار (هكذا اختار التصميم B). إن كان تقنياً محضاً، قرّر أنت ووثّق السبب في `01_CONTEXT.md` أو `08_ERRORS_AND_LESSONS.md`.
- **جمهور التطبيق النهائي:** عامل بقالة قد يكون أميّاً. كل شاشة: أزرار كبيرة، صور، صوت، أوراق نقدية — لا نصوص صغيرة، لا حقول كثيرة.

## 4. خريطة ذهنية سريعة للكود (قبل فتح أي ملف)
| تريد… | افتح |
|---|---|
| أي شيء يلمس المال/الدفتر | `lib/core/ledger/ledger_service.dart` (**الكاتب الوحيد**) + `04_LEDGER_RULES.md` R1–R10 |
| المال والعملات | `lib/core/money/` — `Money(int minor, Currency)` أعداد صحيحة فقط، لا double |
| شاشة جديدة | `lib/features/<اسم>/<اسم>_screen.dart` + مسار في `lib/app_routes.dart` + تسجيل في `lib/app.dart` + بند في `lib/shared/widgets/app_drawer.dart` (إن كان مساراً رئيسياً — D5 يحدّه بـ 9) |
| نص ظاهر للمستخدم | `lib/shared/l10n/ar_strings.dart` (وتسميات أخذ/سدّد عبر `TxLabels.of`) |
| إعداد جديد | `lib/data/repositories/settings_repository.dart` — أضف `k...` ثابتاً + getter/setter |
| جلسة/صلاحيات | `lib/data/session/session_provider.dart` — `AppUser.can('perm')` |
| PDF | `lib/core/docs/` — `DocRenderer` (الأنواع) + `DocLayout` (القوالب JSON) + `PdfHelpers.rtlTable` (E1) |
| نسخ احتياطي | `lib/data/backup/` — الاستعادة `INSERT OR IGNORE` لا تحذف أبداً |
| التفعيل | `lib/core/activation/activation.dart` + `tool/gen_activation.dart` |
| الألوان/الثيم | `lib/shared/theme/app_theme.dart` — لا تغيّر الأساسية بدون `03_DESIGN.md` (WCAG مُدقَّق) |
| زر رجوع | `lib/shared/widgets/app_back_button.dart` — **كل شاشة غير الرئيسية يجب أن تحويه** |

## 5. تعريف "جلسة مكتملة"
- [ ] `flutter analyze` = 0 و `flutter test` كلها خضراء.
- [ ] `07_PROGRESS.md` محدَّث (جدول الجلسة + سجل الجلسات).
- [ ] أي خطأ جديد → `08_ERRORS_AND_LESSONS.md` بصيغة E<n>.
- [ ] أي قرار من العميل → `01_CONTEXT.md` بصيغة D<n>.
- [ ] `git commit` برسالة واضحة + `git push origin main`.
- [ ] إن صدر APK: `CHANGELOG.md` + وسم + GitHub Release (`12_RELEASE_GUIDE.md §8`).
- [ ] ProjectBackup (يحوي التوقيع) وإعطاء الرابط للعميل.
