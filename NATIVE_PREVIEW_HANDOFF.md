# ဘတ်ဈေး native previews

Android and iOS runners are committed rather than recreated during each build.

- Application/bundle ID: `io.github.sharedbyattmaker.bahtzay` (not registered with stores).
- Display name: ဘတ်ဈေး. Existing approved logo is the only artwork source.
- Pinned Flutter: 3.47.7. Android uses JDK 17. iOS simulator requires macOS/Xcode.
- Before building: `python scripts/fetch_fonts.py`, install Pillow 12.3.0, `python scripts/prepare_native_icons.py`, then `flutter pub get` in flutter_app.
- `flutter build apk --debug --dart-define=RATES_API=https://bahtzay-rates.muddyhinny2048.chatgpt.site`
- `flutter build ios --simulator --debug --dart-define=RATES_API=https://bahtzay-rates.muddyhinny2048.chatgpt.site`
- Native preview workflow uploads both results as seven-day artifacts after PR/master runs. These are debug/simulator previews, not store releases. No production signing keys are included. Android release signing must be configured separately.

## Data transfer
Web/PWA and native sandboxes are separate. Export a combined JSON backup from Settings on the existing installation, keep a safe copy, then select it on the native app's complete-backup page. Review the preview and explicitly confirm restore. User chooses where to save/share native exports. No backend upload or automatic transfer is added. Existing record merge, budget replace and rollback behavior remain in CompleteBackupService. Test with disposable data before moving personal records to a new device.

## Advertising
Direct sponsor configuration remains owner-controlled and default OFF. App refresh/expiry is bounded; an offline app cannot promise instantaneous remote changes. There is no AdMob/AdSense production integration. Do not add SDK identifiers, analytics, paid service, interstitials, app-open or rewarded ads as part of a preview build. Account approval/consent/store preparation is a later explicit release step.

## Limits
CI compile success is not a physical phone or store-review test. Native push notifications remain unsupported; Telegram is available. Android/iOS signing, actual hardware validation and store submission remain separate.
