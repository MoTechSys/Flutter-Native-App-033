# كِتابي — Kitabi Bookstore

تطبيق متجر كتب (محاكاة) بـ Flutter — مشروع مقرر تطوير تطبيقات الهاتف.
**الطالب:** علي عبده يحيى · **الحزمة:** `com.kitabibookstore.books`

- تصفح 24 كتاباً حقيقياً في 6 تصنيفات، بحث وتصفية، سلة مع كوبونات، مفضلة، تقييمات، طلبات مع تتبع الحالة.
- كل البيانات في SQLite محلية تُنشأ وتُبذر تلقائياً عند أول تشغيل.
- تسجيل/دخول مع تحقق، واستعادة كلمة المرور برمز OTP في 3 خطوات.
- زر الرجوع يعود خطوة بخطوة داخل كل تبويب ولا يخرج من التطبيق فجأة.

**📱 آخر APK جاهز للتثبيت:** [`releases/Kitabi-v1.1.0.apk`](releases/Kitabi-v1.1.0.apk) · **🛠 كيف تبني APK بنفسك:** [`BUILD_GUIDE.md`](BUILD_GUIDE.md) · **📓 سجل التطوير:** [`docs/SESSION_LOG.md`](docs/SESSION_LOG.md)

التوثيق الكامل: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) · ملاحظات الإصدار: [`docs/RELEASE_NOTES.md`](docs/RELEASE_NOTES_1.0.0.md)

```bash
flutter pub get
flutter test
flutter build apk --release
```
