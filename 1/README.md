# Nawdli express Website Frontend

واجهة موقع تحميل تطبيق Nawdli express مع رابط أدمن خاص، بدون Firebase Storage.

## الملفات

- `index.html`: صفحة التحميل الرئيسية.
- `admin.html`: رابط أدمن مباشر غير ظاهر في الموقع العام.
- `styles.css`: التصميم الكامل.
- `script.js`: يعرض روابط APK الثلاثة من GitHub Releases، ويمكن للأدمن تعديل الروابط في Firestore.
- `public/app-icon.png`: أيقونة التطبيق الحقيقية المستخدمة كشعار و favicon.

## ملفات تضعها لاحقًا داخل `public`

- `hero-video.mp4`: فيديو البانر الرئيسي.
- `hero-poster.jpg`: صورة احتياطية للفيديو.
- لا تحتاج وضع APK داخل `public` إذا كانت GitHub Actions تنشر الملفات في GitHub Releases.

## حل التحميل بدون Storage

لا يمكن رفع ملفات APK من المتصفح إلى Firebase Hosting مباشرة بدون Storage أو Backend.
الحل المستخدم هنا:

- GitHub Actions يبني 3 ملفات APK.
- GitHub Releases يستضيف الملفات مجانًا:
  - `nawdli-express-arm64.apk`
  - `nawdli-express-armv7.apk`
  - `nawdli-express-x86_64.apk`
- الموقع يعرض الروابط الثلاثة، وإذا لم تعمل نسخة يحمل المستخدم الأخرى.

## رابط الأدمن

الرابط الخاص:

- `/admin`
- أو `admin.html`

الأدمن لا يظهر في الهيدر أو الفوتر للزوار.

يمكن فتح `index.html` مباشرة في المتصفح، ولا يحتاج الموقع إلى خادم تطوير.
