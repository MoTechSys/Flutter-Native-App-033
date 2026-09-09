# كِتابي — الوثيقة المعمارية (Architecture)

> تطبيق متجر كتب (محاكاة) — مشروع مقرر Flutter — الطالب: **علي عبده يحيى**
> الحزمة: `com.kitabibookstore.books` · Flutter 3.35.4 / Dart 3.9.2 · Material 3 · RTL

---

## 1. لماذا بُني التطبيق بهذا الشكل؟ (نتائج البحث)

قبل كتابة أي كود بُحث في كيفية بناء متاجر الكتب الحقيقية وفي إرشادات تجربة الاستخدام:

| المصدر | الاستنتاج | الأثر في كِتابي |
|---|---|---|
| Nielsen Norman Group — *Hamburger Menus vs Tab Bars* | القائمة الجانبية (Drawer) تُخفي الوجهات وتُقلّل الاكتشاف؛ شريط تبويبات سفلي بـ 3–5 عناصر أفضل قابلية للاستخدام على الهاتف | **لا قائمة جانبية**. 4 تبويبات سفلية: الرئيسية، التصنيفات، السلة، المفضلة |
| تطبيق جرير (Jarir) | 4 تبويبات سفلية + بحث في الأعلى + الحساب من أيقونة | البحث في أعلى الرئيسية، والحساب/الإعدادات من صورة المستخدم في الرأس |
| وثائق Flutter — `PopScope` / التنقل المتداخل | `WillPopScope` مهجور؛ التبويبات تحتاج `Navigator` مستقل لكل تبويب حتى يعود زر الرجوع خطوة بخطوة | `IndexedStack` + `Navigator` لكل تبويب + `PopScope(canPop:false)` |
| طلب صاحب المشروع | الرئيسية لا تكون طويلة؛ التنقل للأعمق بدل التمرير | رئيسية **ثابتة الارتفاع** (LayoutBuilder) بقوائم أفقية فقط |

---

## 2. خريطة الشاشات (≥ 5 شاشات غير المصادقة)

```
بوابة الترخيص (LockedPage)  ─►  تسجيل الدخول ─► إنشاء حساب
                                    │            └► استعادة كلمة المرور (Stepper 3 خطوات + OTP)
                                    ▼
                               Shell (4 تبويبات، كل تبويب Navigator مستقل)
   ├─ الرئيسية ── تفاصيل الكتاب ── (ورقة سفلية: الوصف/المراجعات CRUD)
   │      ├─ قائمة كتب (بحث/تصفية/ترتيب)
   │      └─ حسابي ── تعديل البيانات / تغيير كلمة المرور / طلباتي ── تفاصيل الطلب / حول التطبيق
   ├─ التصنيفات (2×3 ثابتة) ── قائمة كتب التصنيف ── تفاصيل الكتاب
   ├─ السلة (كوبون + إتمام الطلب) ── تفاصيل الطلب
   └─ المفضلة ── تفاصيل الكتاب
```

   └─ (مدير فقط) حسابي ── لوحة إدارة المتجر ── إضافة/تعديل كتاب · تصنيفات · إحصاءات

**عدد الشاشات الفعلية:** 17 (+ لوحة الإدارة بثلاثة تبويبات ونموذج الكتاب) (الرئيسية، التصنيفات، قائمة الكتب، تفاصيل الكتاب، السلة، المفضلة، الطلبات، تفاصيل الطلب، حسابي، تعديل البيانات، تغيير كلمة المرور، حول التطبيق، تسجيل الدخول، إنشاء حساب، استعادة كلمة المرور) + شاشة القفل.

---

## 2.1 الأدوار: مستخدم عادي ومدير متجر

عند إنشاء الحساب يختار المستخدم نوعه (`SegmentedButton`): **مستخدم** أو **مدير المتجر** — يُخزَّن في `users.role` (0/1).

| القدرة | مستخدم | مدير |
|---|---|---|
| تصفح/بحث/سلة/مفضلة/طلبات/مراجعات/حسابه | ✅ | ✅ |
| **لوحة إدارة المتجر** (من "حسابي") | — | ✅ |
| إضافة كتاب (غلاف من المعرض/الكاميرا أو مولَّد) | — | ✅ |
| تعديل/حذف كتاب (من اللوحة أو من صفحة الكتاب مباشرة) | — | ✅ |
| إضافة/تعديل/حذف تصنيف (أيقونة + لون؛ يُمنع حذف تصنيف فيه كتب) | — | ✅ |
| إحصاءات: الكتب/التصنيفات/المستخدمون/الطلبات/الإيراد/الأكثر مبيعاً | — | ✅ |

أي تغيير من المدير يُكتب في SQLite ويظهر **فوراً** في الرئيسية والتصنيفات والبحث لكل المستخدمين (نفس القاعدة على الجهاز). الـ 24 كتاباً الأصلية هي بيانات ابتدائية فقط ويمكن تعديلها أو حذفها.

**تخزين الأغلفة المُضافة:** على أندرويد يُنسخ الملف إلى `getApplicationDocumentsDirectory()/covers/` ويُحفظ مساره في `books.cover`؛ على الويب يُخزَّن base64 داخل الحقل نفسه. `coverImage()` يختار المصدر تلقائياً (asset / file / data URI / مولَّد).

**ترقية قاعدة البيانات:** `version: 2` مع `onUpgrade` يضيف عمود `role` للنسخ المثبّتة سابقاً دون فقد بيانات (مُغطّى باختبار).

## 3. سلوك زر الرجوع (مطلب أساسي)

```
زر الرجوع ─► PopScope(canPop:false).onPopInvokedWithResult ─► Shell._onBack()
   1) هل Navigator التبويب الحالي يستطيع pop؟  ──► ارجع صفحة واحدة
   2) هل التبويب الحالي ≠ الرئيسية؟             ──► انتقل إلى الرئيسية
   3) في الرئيسية                                ──► حوار "الخروج من كِتابي؟" ── خروج ─► SystemNavigator.pop()
```
- النقر على التبويب الحالي مرة أخرى يعود إلى جذره (`popUntil isFirst`).
- زر "اشترِ الآن" في التفاصيل: `popUntil(isFirst)` ثم `ShellController.go(cart)` كي لا يتراكم المكدس.
- مُغطّى باختبار `flows_test.dart › Shell: زر الرجوع خطوة بخطوة`.

---

## 4. طبقات الكود

```
lib/
├── main.dart                 KitabiApp + _Gate (ترخيص ← جلسة ← تحميل الكتالوج) + Splash
├── app_theme.dart            Palette (night/walnut/gold/ivory) + buildKitabiTheme()
├── models/models.dart        AppUser, Category, Book, CartLine, Order, OrderLine, Review, OrderStatus
├── data/
│   ├── db.dart               KitabiDb (sqflite) — المخطط + البذر عند onCreate
│   ├── seed.dart             6 تصنيفات × 4 = 24 كتاباً حقيقياً
│   └── repos/repos.dart      UserRepo, CatalogRepo, CartRepo, FavoriteRepo, OrderRepo, ReviewRepo
├── state/
│   ├── session.dart          Session (ChangeNotifier) — تسجيل/دخول/خروج/حذف + استعادة الجلسة
│   └── store_state.dart      CatalogState, CartState (كوبونات + checkout), FavoritesState
├── security/
│   ├── access_control.dart   sealed AccessDecision + AccessControl (GitHub API → raw fallback)
│   └── otp_engine.dart       OtpEngine (5 خانات، دقيقتان، 3 محاولات، تهدئة 30 ث)
└── ui/
    ├── shell.dart            IndexedStack + Navigator/تبويب + PopScope + NavigationBar بشارات
    ├── shared/widgets.dart   BookCover(Hero), RatingStars, PriceTag, DiscountRibbon, notify(), confirm(), validators
    ├── auth/                 sign_in, sign_up, recover_password (Stepper)
    ├── lock/locked_page.dart
    ├── admin/                admin_page (كتب/تصنيفات/إحصاءات), book_form_page (إضافة/تعديل + غلاف)
    ├── home/                 home (ثابتة), categories, book_list (بحث/تصفية), book_detail (+ مراجعات + أزرار المدير)
    ├── cart/cart_page.dart   Dismissible + كوبون + إتمام
    ├── favorites/
    ├── orders/               orders_page, order_detail_page (خط زمني + إلغاء + محاكاة تقدم)
    └── profile/              profile, edit_profile, change_password, about
```

---

## 4.1 الأدوار (مستخدم / مدير)

- عند التسجيل يختار المستخدم نوع الحساب بـ `SegmentedButton`: **مستخدم** أو **مدير المتجر** (نفس نمط معلم/طالب في EduAcademy).
- يُخزَّن في `users.role` (0/1). `Session.isAdmin` يتحكم في ظهور:
  - قسم **"إدارة المتجر"** في صفحة حسابي + شارة "مدير".
  - أزرار **تعديل/حذف** في أعلى صفحة تفاصيل أي كتاب.
- **لوحة الإدارة** (`ui/admin/`): تبويب الكتب (بحث + تصفية + إضافة/تعديل/حذف بالسحب)، تبويب التصنيفات (إضافة/تعديل/حذف مع أيقونة ولون؛ يُمنع حذف تصنيف يحوي كتباً)، تبويب الإحصاءات (كتب/تصنيفات/مستخدمون/طلبات/إيراد/الأكثر مبيعاً/توزيع التصنيفات).
- **نموذج الكتاب**: تحقق كامل (عنوان، مؤلف، تصنيف، سعر، سعر قبل الخصم > السعر، صفحات، سنة، وصف ≥ 10)، تقييم ابتدائي، "مميز"، وغلاف من **المعرض/الكاميرا** (`image_picker`) أو غلاف مولَّد بلون التصنيف.
- تخزين الغلاف: أندرويد → نسخ إلى `getApplicationDocumentsDirectory()/covers/` ويُحفظ المسار؛ ويب → base64 داخل SQLite (`cover_store_io.dart` / `cover_store_web.dart` عبر conditional import).
- الكتب المضافة تظهر فوراً في الرئيسية والتصنيفات والبحث لأن `CatalogState` يُعيد التحميل بعد كل كتابة.

## 5. قاعدة البيانات SQLite

- **المسار (أندرويد):** `getDatabasesPath()/kitabi.db` ⇒ `/data/data/com.kitabibookstore.books/databases/kitabi.db` (المسار الافتراضي للنظام).
- **الإنشاء والبذر:** في `onCreate` عند **أول تشغيل بعد التثبيت** تلقائياً: المخطط ثم `seedCatalog()` (24 كتاباً حقيقياً، 6 تصنيفات).
- **الويب:** `sqflite_common_ffi_web` (WASM) — نفس الكود.
- **الإصدار 2**: `onUpgrade` يضيف عمود `role` للنسخ المثبّتة سابقاً دون فقد بيانات (مُغطّى باختبار ترقية).
- `PRAGMA foreign_keys = ON` + `ON DELETE CASCADE` — حذف المستخدم يحذف سلته/مفضلته/طلباته/مراجعاته.

| الجدول | الأعمدة الرئيسية | CRUD في التطبيق |
|---|---|---|
| users | id, name, email UNIQUE, password (SHA-256+salt), phone, city, **role**, created_at | C تسجيل · R دخول/ملف · U تعديل/كلمة مرور/استعادة · D حذف الحساب |
| categories | id, name, slug, color | **C/U/D من لوحة المدير** · R |
| books | id, category_id FK, title, author, description, price, old_price, rating, pages, year, cover, cover_color, featured | **C/U/D من لوحة المدير** · R + بحث/تصفية |
| cart_items | user_id FK, book_id FK, qty — PK مركّب | C/U upsert · R · D (سحب/تفريغ) |
| favorites | user_id FK, book_id FK | C/D toggle · R |
| orders | id, user_id FK, created_at, subtotal, discount, total, coupon, status | C checkout (Transaction) · R · U تقدم الحالة · D إلغاء |
| order_items | order_id FK, book_id, title, unit_price, qty | C/R |
| reviews | id, book_id FK, user_id FK, stars, text, created_at — UNIQUE(book,user) | C/U upsert · R · D |

---

## 6. الترخيص البعيد (`license.json` في جذر المستودع)

| حالة الملف على GitHub | القرار | الشاشة |
|---|---|---|
| `active: true` | `Granted` | يدخل فوراً |
| `active: false` + `code` | `Locked` — يطلب الكود؛ عند صحته يُحفظ ويُفتح تلقائياً في المرات القادمة **ما لم يتغيّر الكود** | LockedPage مع حقل الكود |
| الملف محذوف (404) | `Terminated` — قفل نهائي، لا يقبل أي كود | LockedPage بلا حقل |
| لا إنترنت | `Offline(last)` — آخر حالة محفوظة (Granted افتراضياً لأول تشغيل) | حسب آخر حالة |

المصدر الأول: **GitHub Contents API** (لا يمرّ عبر CDN فلا يتأخر التحديث) ثم `raw.githubusercontent.com` كاحتياط. على الويب لا تُرسل ترويسات Cache-Control (تسبب رفض CORS) ويُستعمل معامل كسر الكاش في الرابط.

---

## 7. استعادة كلمة المرور (OTP)

- 3 خطوات في `Stepper` عمودي: البريد → الرمز → كلمة مرور جديدة.
- الرمز: 5 خانات من أبجدية بلا `0/O/1/I`، يُعرض `XX-XXX`، صلاحية دقيقتان، 3 محاولات، إعادة إرسال بعد 30 ثانية، زر نسخ.
- بعد النجاح `UPDATE users SET password` فعلياً (اختبار يتأكد أن القديمة لا تعمل والجديدة تعمل).

---

## 8. مطابقة معايير الدكتور

| المعيار | التنفيذ |
|---|---|
| ≥ 5 شاشات غير المصادقة | 15 شاشة (+ لوحة الإدارة ونموذج الكتاب) |
| تسجيل/دخول + Form/Validation + نسيت كلمة المرور فعّالة | `vEmail/vPassword/vName/vPhone` + OTP حقيقي يغيّر كلمة المرور |
| تنويع Widgets | Stepper, Hero, DraggableScrollableSheet, TabBar, Dismissible, Badge, NavigationBar, PopupMenu, Chips, Dropdown, Checkbox, Wrap, Card, AlertDialog, SnackBar… |
| صور من Assets | 24 غلاف `assets/covers/` + `assets/brand/` |
| Row/Column/Stack | في كل الصفحات؛ Stack في الغلاف والبانر و"حول" |
| ListView/GridView | قوائم أفقية/عمودية + GridView (التصنيفات، الكتب، المفضلة) |
| StatefulWidget | Shell, BookDetail, Cart, BookList, Recover… |
| SnackBar + Dialog | `notify()` و`confirm()` + حوار الخروج + حوار المراجعة |
| SQLite CRUD | القسم 5 — CRUD كامل على **كل** الجداول بما فيها الكتب والتصنيفات (لوحة المدير) |
| التنقل مع تمرير بيانات | `BookDetailPage(book:)`, `BookListPage(categoryId:)`, `OrderDetailPage(order:, justPlaced:)` |
| تنظيم متعدد الملفات | 30 ملف Dart في 9 مجلدات |
| APK قابل للتشغيل | `flutter build apk --release` موقّع |

---

## 9. الاختبارات (`flutter test`)

| الملف | يغطي |
|---|---|
| `repos_test.dart` | البذر الحقيقي (24/6)، CRUD كامل لكل مستودع، Transaction، CASCADE |
| `security_test.dart` | 4 حالات الترخيص بـ MockClient، محرّك OTP |
| `flows_test.dart` | تحقق النماذج، مسار OTP كامل، زر الرجوع خطوة بخطوة، حوار الخروج، لا Overflow على 360×780 |
| `admin_test.dart` | الأدوار (تسجيل مدير/مستخدم)، ترقية v1→v2، CRUD الكتب والتصنيفات، CASCADE عند حذف كتاب، الأكثر مبيعاً، ظهور لوحة الإدارة للمدير فقط، نموذج إضافة كتاب يحفظ في SQLite |
| `admin_test.dart` | الأدوار (مدير/مستخدم)، ترقية v1→v2، CRUD الكتب والتصنيفات، الأكثر مبيعاً، ظهور اللوحة للمدير فقط، نموذج إضافة كتاب يحفظ فعلاً |

---

## 10. الاختلاف عن المشروعَين السابقَين (011 CarCare / 022 EduAcademy)

- نمط تنقّل مختلف كلياً: تنقّل متداخل لكل تبويب بدل Navigator واحد.
- حالة عبر `ChangeNotifier` منفصلة (Session/Catalog/Cart/Favorites) بدل خدمة واحدة.
- `sealed class` لقرار الترخيص مع `switch` نمطي بدل enum.
- OTP أبجدي-رقمي 5 خانات بصيغة `XX-XXX` بدل 4 أرقام.
- ثيم داكن فاخر بخط Serif وأغلفة مولّدة إجرائياً (Pillow + libraqm) بدل صور شبكية.
