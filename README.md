# استبيان مختبرات Nor

تطبيق Flutter يعمل دون اتصال بالإنترنت لتسجيل إجابات استبيان استخدام القفازات في المختبرات الطبية، مع حفظ محلي وتصدير Excel أو JSON.

## البناء محلياً

```bash
flutter pub get
flutter run
```

## بناء APK عبر GitHub Actions

يتم البناء تلقائياً عند الدفع إلى `main` أو يدوياً من تبويب Actions عبر workflow باسم **Build APK**. ملف APK يظهر كـ artifact باسم `survey-apk`.
