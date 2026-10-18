# ဘတ်ဈေး · Currency app

## Live app and daily administration

- Public app: https://sharedbyatt-maker.github.io/thai-helper-app/
- Daily rates administration: https://bahtzay-rates.muddyhinny2048.chatgpt.site/admin/index.html
- Public rates API: https://bahtzay-rates.muddyhinny2048.chatgpt.site/api/v2/rates

The hosted backend uses ChatGPT Sites with a durable Cloudflare D1 database. No paid Render service is required or provisioned. Sites account terms and availability apply; this is not a promise of unlimited hosting or permanent pricing.

Sign into the dashboard with the ChatGPT account that owns this Site. The initial owner is checked against the trusted Sites access record, then its Site-specific identity is pinned in the database. Other signed-in accounts cannot edit rates. No new password, API key, or activation code is needed.

Enter separate THB→MMK and MMK→THB prices in baht per 100,000 MMK, confirm that you checked each updated price, then **Save Draft → Preview → Publish**. Drafts stay private. The app refreshes about once a minute. No invented live rates are supplied: the owner must publish the first real daily sheet.

`hosted_backend/` retains the deployed backend source, migrations, tests and Sites build integration. Its native Site source repository is synchronized separately by the Sites workflow. Personal transaction records remain browser-local, not in the shared backend.

The GitHub Pages workflow uses this hosted API by default. Set the optional repository Actions variable `RATES_API` to a different origin when migrating. The Flutter client itself retains same-origin API behavior when built without that define, suitable for the optional Python/Docker deployment below.

## Simple daily workflow

The public calculator starts with amount and rate only. Comparison and target-payout options are collapsed. The public app has no source-details drawer or editable deduction inputs. Legacy nonzero published deductions remain a read-only notice and stay included in results; editing a rate clears legacy deductions so manual prices never silently retain them. The calculator uses a compact centered layout, large numeric entry and highlighted results. The rate board preserves a real chart marker or an explicit empty chart frame when history is limited.

The hosted admin form has one independent per-lakh input for each direction, faded examples, an equivalent-rate explanation, a check confirmation and a daily recheck shortcut. Source/provider and fee inputs are removed; internal generic provenance remains for compatibility. Existing quote IDs survive daily edits and re-adding a direction. Time fields are optional details. Unchanged legacy deductions are preserved transparently; typing a new price clears them. Example numbers are never saved as actual prices.

## User interface and rate trend

The public board opens with the 7-day chart, with Today / 7-day / 30-day choices, selectable observations, low/high summaries and independent directional price cards. `/api/v2/history` returns daily points and deduplicated timestamped observations from immutable publications. Today shows real intraday updates; longer periods use the last observation per Bangkok day. The chart follows a stable published quote ID, direction and payout method across optional display/source-name changes; each observation retains its own source name for inspection. It never fills missing dates or invents rates. A single observation is a visible point and value; zero observations retain a labeled chart frame. Both directions display baht per 100,000 MMK consistently, using their separately entered rates. Calculator entry uses the selected published rate when available and preserves personal comparison entries and budget on refresh. Cache/storage failure does not prevent online rate reads. Displayed chart rates exclude fees. The optional standalone Python backend does not currently expose the history endpoint; its calculator and daily sheet remain usable.

## Features

Currency-only tools for Myanmar users: owner-published directional quotes, personal quote comparison, timestamped price sharing, opt-in Telegram price alerts, and device-local exchange records with backup import/export. Thai language features and simulated provider rankings are not part of the active app.

## What the owner does each day

1. Open `/admin` and sign in.
2. Add or edit **ဘတ်ပေး → ကျပ်ယူ** and **ကျပ်ပေး → ဘတ်ယူ** separately. Neither direction is inferred from the other.
3. Enter baht per 100,000 MMK. Updating the price sets the observation time to now and freshness to 24 hours. Expand time details only when you need to record a different check time.
4. Confirm the updated price was checked, save Draft, then Preview. The daily recheck shortcut can confirm an unchanged price without typing it again.
5. Publish. Public clients refresh automatically once per minute and can pull to refresh. Unpublished drafts remain private.
6. To correct a mistake, restore an earlier version to Draft, review its rate/expiry, then publish a new version. Restoring alone does not change public data.

Empty publishing is supported to withdraw all quotes. Expired or future quotes are visible with a warning but cannot be selected for calculation. A successful source check is not a guarantee about an exchanger or payment completion.

## Optional standalone Python deployment

Use Flutter **3.47.7**, Dart **3.13**, Python **3.12**. Font files are fetched once from a pinned Google Fonts commit and SHA-256 verified at build time; the built app bundles them for offline use. The same server can serve the Flutter build, public API and admin dashboard; this avoids cross-site login problems.

```bash
python scripts/fetch_fonts.py
cd flutter_app
flutter pub get
flutter analyze
flutter test
flutter build web --release --no-web-resources-cdn
cd ..
python -m venv .venv
.venv/bin/pip install -r backend/requirements.txt
.venv/bin/python backend/set_password.py
```

The password helper prompts without echoing and prints a password hash. Set that output as the server's `ADMIN_PASSWORD_HASH` environment variable. There is no default password. Do not commit credentials.

For local HTTP development only, set `COOKIE_SECURE=false`. Run:

```bash
.venv/bin/python backend/app.py
```

Then open `http://127.0.0.1:5000` and `http://127.0.0.1:5000/admin`.

For production use HTTPS, `COOKIE_SECURE=true`, and a **persistent writable disk** for `EXCHANGE_DATABASE`. The default path is `backend/instance/exchange.sqlite3`. A temporary filesystem loses rate versions and sessions when the host restarts. The database uses WAL and transactions; use SQLite's backup API or stop the service for a consistent backup, rather than copying only the main database file while it is running.

```bash
cd backend
gunicorn --bind 0.0.0.0:8000 --workers 2 app:app
```

If the service sits behind exactly one trusted HTTPS reverse proxy, set `TRUST_PROXY=true` so the admin same-origin check sees HTTPS. Do not enable that setting on a server directly reachable around the proxy. Proxy-forwarded IPs are not trusted for authentication throttling.

`Dockerfile` builds the web app and serves everything on port 8000. `render.yaml` is an optional Render blueprint using a **paid** persistent disk service; review hosting costs before deployment. This repository change does not create a hosting account or deploy a paid service. The container user (UID 10001) must be able to write to `/data`.

## GitHub Pages deployment

The public Flutter build stays on GitHub Pages; the daily-rate API and admin run on Sites. `Publish currency web` builds with the hosted API origin by default. An optional `RATES_API` Actions variable can override it. Missing network access falls back to a cached sheet or empty bundled sheet, while personal calculators keep working. No market quotes are invented.

The previous scheduled estimated-provider updater is removed. Legacy data and archived phrasebook files are not read by this UI or the publishing API.

## Calculator contract

- Amounts accept Myanmar, Thai and English digits, commas and up to two decimal places.
- Quotes store MMK per THB as integer millionths. Both paying and receiving amounts use 1/100 minor units.
- **Input is total spending, including fees.** `fee = flat + ceil(total × percentage)`; payout converts the remaining amount and rounds down to a minor unit.
- Target-payout calculation returns the smallest total budget that meets the target using the chosen flat/percentage fee. It does not use the previous global search across stepped provider fees.
- The calculator compares at most three quotes in the same direction. A comparison assumes the user has checked matching payout methods and conditions.
- The legacy rate parser remains covered by unit tests; its calculator paste UI has been removed. Parser examples: `1 THB = 125 MMK`, `၁ ဘတ် = ၁၂၅ ကျပ်`, `၁ သိန်း = ၈၀၀ ဘတ်`. These numbers are **format examples, not real quotes**. Ambiguous/multiple different rates are rejected. Screenshot OCR is not included.
- Source-selected quotes lose their checked-source provenance when the user edits them. Expired source quotes cannot be calculated as current quotes.

## Personal records

No customer login is needed. Rate snapshots, amounts and optional notes are stored using SharedPreferences on the current device/browser; no personal records are sent to the publishing backend. Users can mark a saved calculation as completed, choose the actual completion date, delete records, download JSON, and preview a non-destructive JSON import. Completion is user-reported, not independently verified.

Monthly summaries keep THB→MMK and MMK→THB totals separate and include only completed records. They use the actual completion date, falling back to the save date for older records without a completion date. Limits: 500 records; browser storage can be cleared or lost; no cross-device sync. Export important records. Corrupt stored data is not silently replaced.

## Security and operational limits

The optional Python backend has hashed-password login, random server-side sessions (8 hours), HttpOnly/Secure/SameSite cookies, CSRF tokens, origin checks, database-backed login throttling, draft version conflict detection, immutable published revisions and safe DOM rendering. Changing the password hash invalidates prior sessions. Source URLs are limited to HTTP(S).

There are no payment handling, public seller listings, referral click tracking, unprotected statistics or claimed exchanger trust badges. This is not an audited production financial system: owner source checks, hosting configuration, backups and fresh quotes remain required.

## Checks

```bash
python -m pip install -r backend/requirements.txt pytest
python -m pytest backend/tests -q
npm ci --ignore-scripts
node --check backend/admin/app.js
npm run test:admin
cd flutter_app
flutter analyze
flutter test
flutter build web --release --no-web-resources-cdn
```

CI runs backend checks plus Flutter analysis, tests and web build for pull requests. Publishing is a separate workflow after merge/manual dispatch.

### Telegram မှ နှုန်းတင်ခြင်း (hosted backend)

Admin → **စာပို့ပြီး နှုန်းတင်မယ်** → Settings:

1. Telegram [@BotFather](https://t.me/BotFather) မှာ `/newbot` ဖြင့် ကိုယ်ပိုင် bot ဖန်တီးပါ။
2. ရသော token ကို Admin ရဲ့ password အကွက်ထဲ ထည့်ပြီး ပြမည့်အမည်ကို လိုမှဖြည့်ကာ **Bot ချိတ်မယ်** နှိပ်ပါ။ Token ကို GitHub သို့မဟုတ် chat ထဲ မတင်ပါနှင့်။
3. **ငါ့ Telegram ချိတ်မယ်** နှိပ်၊ ပေါ်လာသော link ဖြင့် Telegram မှာ Start နှိပ်ပါ။ Link သက်တမ်း ၁၀ မိနစ်ဖြစ်ပြီး တစ်ခါသာသုံးနိုင်သည်။ ချိတ်ပြီးသော Telegram account တစ်ခုတည်းက နှုန်းတင်နိုင်သည်။

Daily: Channel ရွေးရန်မလိုပါ။ ဘယ် channel ကစာမဆို ကူးပို့နိုင်သည်။ `ကျပ်ပေး ဘတ်ယူ 726` သို့မဟုတ် `726` ပို့ပါ။ **ကျပ် ၁ သိန်း = ဘတ် 726** ဖြစ်သည်။ နံပါတ်တစ်ခုတည်းပို့လျှင် Admin တွင် သတ်မှတ်ထားသော ဦးတည်ချက်ကို သုံးသည်။ Viber စာအပြည့်တွင် နှုန်းများပါလျှင် ၁၀ မိနစ်သက်တမ်းရှိ ခလုတ်များမှ တစ်ခုသာရွေးနိုင်သည်။ တစ်ဘက်နှုန်းရလျှင် အခြားဘက်ပါ ထည့်ဦးမလား မေးပြီး ထည့်မယ်ဆို သီးခြားနှုန်းကို ဆက်ပို့နိုင်သည်။ မထည့်သေးဆို ယခင်အခြားဘက်နှုန်းကို မူလစစ်ချိန်အတိုင်း ဆက်ထားပြီး မရှိလျှင် အလွတ်ထားသည်။ နှစ်ဘက်နှုန်းကို အလိုအလျောက် ပြန်မတွက်ပါ။ နမူနာအချက်အလက်ကို အရင်ပြပြီး **မှန်တယ်၊ Public တင်မယ်** နှိပ်မှသာ တင်သည်။ **မတင်တော့ဘူး** သို့မဟုတ် `/cancel` ဖြင့် ရပ်နိုင်သည်။ အတည်မပြုမချင်း public rates / history / Admin draft ကို မပြောင်းပါ။ စာအသစ်ပို့လျှင် ခလုတ်ဟောင်းကို ပိတ်ပြီး Admin မှ Public နှုန်းပြောင်းထားလျှင် နမူနာအသစ် ပြန်စစ်ရသည်။ ငွေပမာဏအဆင့်များ၊ fee နှင့် OCR မပါပါ။ `/status` ဖြင့် နှုန်းကြည့်၊ `/undo` ဖြင့် နောက်ဆုံး Telegram တင်ချက်ကို ပြန်ဖျက်နိုင်သည်။

နှုန်းကို public rates နှင့် trend history သို့ တင်သည်။ ၂၄ နာရီကျော်လျှင် ပြန်မစစ်ရသေးသောနှုန်းဟု ဆက်ပြပြီး လက်ရှိနှုန်းအဖြစ် မတွက်ပေးပါ။ နှုန်းမှတ်တမ်းကို မဖျက်ပါ။ ရှိပြီးသား ဦးတည်ချက်တူနှုန်းကို အစားထိုးပြီး သီးခြား ပြောင်းပြန်ဦးတည်ချက်ကို မခန့်မှန်းပါ။ Draft သည် published နှင့် တူနေမှ sync လုပ်ပြီး မတင်ရသေးသော Draft ကို ထိန်းထားသည်။ Telegram တင်ပြီးနောက် Admin ကို Reload လုပ်ပါ။

Hosting secret `TELEGRAM_CONFIG_KEY` သည် random 32-byte hexadecimal key ဖြစ်ရမည်။ Native Sites environment secret အဖြစ်သာ သိမ်းပြီး deploy လုပ်ရသည်။ Bot token/webhook secret ကို AES-GCM ဖြင့် encrypt လုပ်ကာ D1 တွင် သိမ်းသည်။ Key ကို အလိုအလျောက် မပြောင်းပါနှင့်။ Token ကို UI/API က ပြန်မပေးပါ။ Webhook သည် Telegram secret header၊ paired sender၊ private chat နှင့် durable duplicate receipt ကို စစ်သည်။ အသစ်ထည့်ထားသော Drizzle migrations ကို deploy ဖြင့် apply လုပ်ရသည်။ Local Python backend တွင် Telegram integration မပါပါ။

## Confirmed six-day history replacement

The owner approved replacing the previous published price history and draft with six daily observations on 2026-10-17. Values below are baht per 100,000 MMK; MMK→THB uses the first (3-lakh minimum) price from the supplied screenshots. Only the last visible update on each confirmed date is included.

| Bangkok date | Source time | MMK→THB | THB→MMK |
| --- | --- | ---: | ---: |
| 2026-10-12 | 19:28 | 738 | 760 |
| 2026-10-13 | 16:19 | 733 | 755 |
| 2026-10-14 | 19:14 | 720 | 745 |
| 2026-10-15 | 12:00 | 706 | 740 |
| 2026-10-16 | 17:12 | 724 | 748 |
| 2026-10-17 | 12:31 | 724 | 748 |

`confirmed-history.mjs` contains the fixed dataset and a one-use operation protected by a high-entropy capability hash. No plaintext capability is stored in source. The operation checks the current revision and draft version, archives prior revisions and the draft in `history_replacements`, replaces prices in one atomic D1 batch, increments the draft version and invalidates prior pending Telegram confirmations. Account settings, bot configuration and receipts are retained. The receipt prevents any later retry from erasing new owner publications. Actual source observation times and 24-hour freshness are retained; publication timestamps record the import time. Schema migrations contain only the added archive/receipt table.

Phone layouts use fully wrapping, equal-height direction cards without chip avatar/fade constraints. The mobile trend card uses a 108px plot, compact periods/summary and fewer repeated labels; desktop retains the detailed 158px chart. Responsive tests load the real Myanmar fonts and check 320–430px widths, larger accessibility text, glyph selection bounds, six real points and card height.


## Daily-use tools and subscriber alerts

- Home retains a separate personal amount for each direction on this browser. It shows the payout and difference against the most recent actual earlier Bangkok day; a missing yesterday is labeled by its actual date. Freshness checks also apply here. Prices and reverse prices are never invented.
- Planned dates are local notes shown when the app is opened, not background calendar notifications. Home Screen installation is offered after repeat visits. It uses the browser install prompt when available and otherwise gives iPhone/Android instructions.
- The daily share card contains public prices, original observation times, stale labels and the app URL. It excludes private amounts, notes, records, and source names. A PNG can be shared or downloaded when native file sharing is unavailable.
- JSON import validates the whole backup before offering a count preview. It merges by record ID, skips duplicates without replacing existing records, and enforces the 500-record limit. Export/import and PNG download are provided for the deployed web app.
- The daily Admin editor accepts baht per 100,000 MMK with independent prices and stable per-direction feed IDs. Source/provider and fee inputs have been removed. Untouched legacy deductions remain honestly preserved; entering a new price explicitly clears them. Unchanged expired opposite quotes may be carried forward with their real observation time alongside a fresh direction.
- A user chooses the bell on Home, selects daily-price news or a target, opens Telegram, and presses Start. News uses `news_thb_mmk` / `news_mmk_thb`; one-shot targets use `watch_<direction>_<hundredths-of-baht-per-lakh>`. THB→MMK targets mean at or below; MMK→THB means at or above. The bot stores only the Telegram chat ID, direction, mode and target needed for delivery. `/stop` disables sends; resubscribing invalidates older queued messages. Public subscribers never obtain owner publishing privileges.
- Notifications evaluate only confirmed, fresh publications. Same-day unchanged rates and carried opposite rates are suppressed. A new day's confirmation may send the same price again. Target alerts stop after a successful send. The queue has bounded batches, leases, Telegram backoff, and expiry checks. Publishing, public rate reads and Admin insight refresh resume pending work through the Worker request's background lifetime. There is no independent minute-by-minute cron: delivery can be delayed during Telegram/network failure until another publication/read/insight refresh. External delivery is at least once; a rare ambiguous network timeout can result in a repeated message.
- Admin insight counts show active subscriptions and queued/delivered messages. Personal record amounts and browser usage are not sent to the publishing backend. Published data and existing owner/bot settings are not changed by these additive schema migrations.

### Phone notifications (Web / Home Screen app)

The bell dialog offers an explicit phone-notification opt-in and a separate Telegram option. iOS/iPadOS 16.4+ users must first add the site to the Home Screen and open that icon. A browser permission prompt is triggered only by the user's enable button. A scoped device token protects status, self-test and unsubscribe requests; subscription writes allow only the public app origin and the backend's own origin.

Confirmed Admin price publications and confirmed Telegram prices create an event in the same database transaction as the public revision. Admin has a separate announcement publisher; the paired Telegram owner can use `/announce <message>` and must confirm the preview. Announcements retain all original rate observation times and preserve independently edited drafts. Private drafts, canceled previews and publication removal do not create phone events. Every explicit publication is eligible, including a repeated same-day price. New opt-ins start at the current revision and do not receive historical posts.

Web Push uses RFC 8291 encryption and RFC 8292 VAPID with Worker-native Web Crypto. VAPID private material is generated once, encrypted using the existing `TELEGRAM_CONFIG_KEY`, and never returned by the public API. Do not rotate that runtime secret: it also protects the connected Telegram bot. No Firebase project or Apple developer membership is needed for this web push path. Future native APK/IPA push integration is a separate task.

The build runs `node ../scripts/prepare_web_push.mjs build/web` to append the phone handler to Flutter's generated service worker, keeping a single scope and existing asset caching. Both check and publishing workflows run this step. Keep `bahtzay-push-sw.js` and `push-client.js` in the web output. If adding a custom website domain, add that exact origin to the backend subscription allowlist.

A confirmed publication starts background delivery immediately. Durable delivery leases prevent concurrent workers from claiming the same item; retry backoff, expiry, changed subscriptions and superseding posts are rechecked before sending. A five-minute GitHub Actions workflow resumes queued sends through the existing public rates endpoint even when no user has the app open. GitHub schedules can be delayed or paused by GitHub; they are a retry aid, not a precise delivery guarantee. Device permissions, connectivity and Focus/Do Not Disturb can also affect display. Push-service acceptance counts are not proof that a person saw the alert.

Use “Noti စမ်းကြည့်မယ်” on an opted-in phone to verify delivery to that device only. There is no public broadcast/test-all endpoint. Never publish fake live rates to test notifications. Browser-local money amounts and personal records are never included in notification payloads. The web privacy page describes local storage, push subscription data and stopping notifications.


### Android app release updates

The owner can manage APK and Google Play releases under Admin → Android App update. Nothing is announced until a real release is enabled. The public read-only `/api/v2/app-release` endpoint returns only enabled channels; unpublished URLs and notes stay private. Changes use an independent release version check, preserve rate drafts/history, and never generate price notifications. Publishing the first enabled release locks the package ID; build numbers cannot go backwards. Updates can be disabled or their notes/download links corrected without modifying prices.

On Android, the client reads the actual package ID, version, build number and installer through `package_info_plus`. Play installations use the Play channel; direct APK installations use APK releases. An app-ID mismatch or invalid URL cannot open a different app. App startup and foreground resumes check for updates, at most once per six hours in an open session. Dismissing a build snoozes its automatic notice for one day; a newer build has a separate notice. The information dialog offers an explicit check that bypasses snoozing. Offline/errors never block the calculator. Download opens the browser or Play Store; Android/the Store still asks the user to update. The app never claims a downloaded release is installed.

The Website/Home Screen app does not receive APK prompts. Its information dialog explains how to reopen the web app. Web service-worker phone notifications remain independent of native Android push.

Before the first APK release: generate the Android platform scaffold (not yet checked in), select the permanent package ID, configure release signing and securely back up the signing key outside Git, enable Android INTERNET access, build with the hosted RATES_API value, and test installation plus an upgrade on real phones with personal records present. Upload the actual signed APK to a stable HTTPS download location such as GitHub Releases before enabling its metadata. Enter its real version name and build number. Google Play releases should be enabled only after that version is available to the intended users. Coordinate Play App Signing with the original APK signing identity if both channels must update the same installations. Release metadata alone does not create or sign APKs, migrate browser-local records into native storage, or add native push/file handling.

`package_info_plus` is pinned to 9.0.0 to stay compatible with the project's existing win32 5.x dependency graph; the lockfile includes the verified package archive hashes. Upgrade that dependency separately with native platform verification.


### Private personal budget

“ကိုယ့်ငွေစာရင်း” opens a separate page from the daily board and exchange records. The three main tabs remain. All budget data stays in `bahtzay_budget_v1` in device/browser preferences; no budget endpoint, analytics event or server upload is added. The exchange-record key and published rates stay separate.

Record actual income (salary, day wages, overtime, tips or support), expenses and completed family remittances in THB integer minor units. A remittance can also retain the actual MMK received, plus a timestamped reference quote. Only the separately published THB→MMK quote is offered for planning. Missing opposite quotes are never inverted. Public price changes do not reprice saved remittance receipts. Upcoming income and future-dated actual transactions are not counted as cash.

Plans have start and next-income dates, a total fixed-bill allocation, a family-remittance allocation and a total savings amount to protect. Actual expenses marked as using fixed reserves reduce the bill allocation; completed remittances reduce the home allocation once. Available money is actual balance less the outstanding allocations and protected savings, preventing double deduction. Daily estimates use only available cash through the next-income date. Periods cannot overlap. Old reservations remain protected after a period ends until the user changes/removes the plan or a new period takes effect. Savings are a protected total, not an automatically added monthly contribution. Plans and transactions can be edited or deleted with confirmation.

Calendar-month summaries independently show actual income, spending, remittances and category bars. Opening balance is not counted again as income. Personal monetary data is not included in price notifications. There are no example transactions or fictitious balances in live storage.

Backup exports the budget's own versioned JSON. Web users can download the file; both web and future native builds offer an explicit copy/paste backup path. Restore validates the entire file, previews replacement, and requires confirmation before replacing budget data. Exchange history is unaffected. Unsupported/corrupt data is never silently cleared; explicit recovery requires a valid confirmed backup. Reads reload preferences and writes reject a stale saved revision, helping prevent stale-tab overwrites; preferences are device-local rather than a cross-device transactional database. Keep a backup before moving devices or clearing browser data. The initial limits are 2,000 transactions, 120 plans and a 2 MB encoded dataset. The native file picker remains part of first-APK platform work.
