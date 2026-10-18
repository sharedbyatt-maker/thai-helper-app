# User View Audit — 18 October 2026

Scope: public Flutter Web/PWA. Source: flutter_app/lib/exchange/. The admin API, Cloudflare D1 database, rate publishing and monetary calculation rules are out of scope.

## Screen-by-screen audit

| User View component | Source | Findings and checks |
|---|---|---|
| App shell and navigation | exchange_app.dart | Approved four-tab order preserved; language selector in header. Theme, preferred direction and locale preference stay independent. |
| Daily rates | exchange_app.dart, rates_repository.dart | Published THB→MMK and MMK→THB directions remain independent; timestamp/origin/cache/freshness are displayed. Do not fabricate missing prices. |
| Rate charts | trend_card.dart, rate_history.dart | Today/7/30-day views, low/high, zero/one observation, timestamp and stale-data messaging. Do not fabricate chart points. |
| Calculator | exchange_app.dart, models.dart | Amount, comparison, payout target, receipts, share results, fee notices, incomplete inputs and recent-rate warnings. Calculation logic unchanged. |
| Exchange records | exchange_app.dart, storage.dart | Local pending/completed records, monthly summary, direction filter, edit/delete, import/export and stale-write protection. Preserve user-entered names and notes. |
| Money management | budget_page.dart, budget.dart | Salary, daily wages, overtime, spending, actual remittances, savings, reserves, available/daily budget, monthly charts, edit/delete. Keep as third tab. |
| Budget editors | budget_page.dart | Form hints, category selector, calendar date prompts, planning periods, input errors and fixed-bill reserve all need bilingual UI checks. |
| Combined backup | complete_backup_page.dart, complete_backup.dart | Preview, explicit replacement consent, additive exchange history, local import/export and best-effort rollback. Never translate JSON data/schema fields. |
| Daily tools | daily_tools.dart | Personal comparison, planned exchange date, Telegram alerts, share graphic and Add to Home Screen instructions. |
| Phone push | phone_notifications.dart | Status, enable/disable, unsupported browser, test notification and private-data disclosure. |
| App update | app_updates.dart | Web/PWA and Android Play/APK channels; do not claim native APK available without verified build. |
| Layout/accessibility | four_tab_navigation_test.dart and other widget tests | Myanmar 320px and 1.4x text scaling already covered; English menu and budget retention tests added here. |

## Localization implementation

- Keep Burmese as the default and add English in the app header.
- Persist selected value as my/en under the new user_language preference key.
- Translate visible static text, navigation labels, input labels/hints and accessible tooltips using shared user-language context.
- Do not rewrite persisted financial data, exchange-rate sheet, quote IDs or user-created notes.
- Preserve public brand name ဘတ်ဈေး in web manifest; language selector applies only to the Flutter public UI.
- Unmapped text remains in its original language, not an invented translation or placeholder.

## Remaining audit limitations

1. Static source review and GitHub CI are not equivalent to hands-on testing on a physical iPhone, Android device or all desktop browsers.
2. SharedPreferences across simultaneous tabs is optimistic concurrency protection, not a fully atomic transactional database.
3. Browser storage clearing can still delete personal records if users have not exported a backup.
4. There are no tracked native signed Android/iOS builds in the web repository.
5. User-generated notes and remote text remain as originally entered/published; only interface copy should be translated.
6. Existing data-integrity, rates and backend rules are intentionally untouched.
7. Any Burmese UI text left without an approved English entry must be identified and translated before claiming 100% English completeness.

## Regression and release gate

Pass Flutter analysis, full widget tests, web release build, Python backend tests, admin tests, branding and push browser tests. Verify the post-merge GitHub Pages deployment. No physical-device verification is claimed.
