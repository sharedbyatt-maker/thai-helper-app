# Thai Helper — Flutter App (v1 scaffold)

## ငါလုပ်ပေးပြီးတာ (code 100%)
- `lib/main.dart` — app entry
- `lib/models.dart` — Phrase/Category + JSON loader
- `lib/services.dart` — on-device TTS (th-TH) + favorites/gender prefs
- `lib/screens.dart` — Home, Category, Phrase detail, Search, Favorites, Settings
- `assets/data/phrases_v1.json` — စကားစု ၁၃၅ ခု
- `pubspec.yaml` — dependencies (flutter_tts, shared_preferences)

## မင်းလုပ်ရမှာ (၃ ဆင့်)

### 1. Flutter install လုပ် (တစ်ခါတည်း, ~၃၀ မိနစ်)
https://docs.flutter.dev/get-started/install — OS အလိုက် လမ်းညွှန်အတိုင်း။
ပြီးရင် terminal မှာ:
```
flutter doctor
```
Android toolchain ✓ ဖြစ်ရမယ်။

### 2. Project run
```
cd flutter_app
flutter pub get
flutter run
```
(ဖုန်း USB ချိတ် developer mode ဖွင့်, ဒါမှမဟုတ် emulator)

### 3. APK ထုတ် (ဖြန့်ဖို့)
```
flutter build apk --release
```
APK က `build/app/outputs/flutter-apk/app-release.apk` မှာ ရမယ် —
Facebook ကနေ တိုက်ရိုက်ဖြန့်လို့ရတယ် (Play Console restricted ဖြစ်နေဆဲ).

## မင်းဆုံးဖြတ်ရမှာ
1. **App နာမည်** (ဥပမာ: ထိုင်းအကူ, ไทยช่วยเพื่อน, ...)
2. **ထိုင်းလူ စစ်ဆေးချက်** — phrases_v1.json ကို ထိုင်းတစ်ယောက်ပြပြီး ပြင်ခိုင်း
3. iOS ထုတ်ချင်ရင်: Apple Developer $99/နှစ် + Mac/CI

## သတိ
- ထိုင်းစာသားတွေ native speaker မစစ်ရသေးဘူး (beta အဆင့်)
- `flutter_tts` version pub.dev မှာ အသစ်ထွက်ထားရင် `flutter pub upgrade` လုပ်
- Code ကို compile မစမ်းရသေးဘူး — `flutter run` မှာ error တက်ရင် ပြန်ပြော, ငါပြင်ပေးမယ်
