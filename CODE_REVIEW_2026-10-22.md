# User and Admin review — 22 October 2026

Baseline: master b2e01e98118c088fd42973561c92a83fb65ebc1e.

## Reviewed scope
User rates/history refresh and provenance, calculator and saved receipts, local wallet and restore flows, four-tab navigation/settings/language, native file adapters, sponsor default-OFF behavior; Admin shared transport, owner enrollment, drafts/preview/publish/history, Telegram, release channels, responsive navigation, server owner checks and existing API validation. This is a focused source review and regression pass, not proof that every possible defect is absent.

## Findings fixed
- A live rate response could be lost on the next offline refresh when browser caching was blocked. Retain the latest server response in session memory, label fallback as cached, and bound optional cache writes to one second. A deliberate server withdrawal remains authoritative; late overlapping responses cannot replace the newer session fallback.
- Combined and wallet-only restore pickers allowed other backup actions while file selection was pending. Lock competing actions, release them on cancellation/error, and clear an older wallet preview after file-read failure. Wallet-only file selection also uses the existing native adapter.
- Admin first-time owner enrollment could recurse without a bound if the server continued returning bootstrap_ready. Share one enrollment request across concurrent reads and permit one retry only. Server authorization is unchanged; no automatic retry follows an uncertain network write.
- Discarding release-channel edits left an unsaved shared package ID in the next channel. Restore it from saved release state after confirmation; cancellation preserves the edits.
- Admin section buttons now identify their panels, panel headings receive keyboard focus on navigation, decorative icons are hidden from screen readers, and errors are announced and scrolled into view. Narrow-screen form controls use 16px text and long labels can wrap. Updated asset hashes prevent stale JS/CSS.

## Validation
- Flutter analyze: no issues. All 121 Flutter tests pass, including narrow layouts/enlarged text, English/Myanmar, calculations, local data conflicts, backup safety, sponsor shutdown and native file adapter checks.
- 21 Admin DOM tests pass; 77 hosted-backend/branding/push checks pass; 23 Python backend tests pass. JS syntax and diff whitespace checks pass.
- No migrations, rate publications, test notifications, paid services or ad activation. Original logo pixels, app name, conversion math, local storage schema and four-tab order are preserved.
- Managed preview started, but the cloud browser received ERR_CONNECTION_REFUSED. Browser visual QA and live authenticated owner interactions are unverified. Automated DOM/widget checks are not claimed as physical-device tests.

PR, CI and deployment results are recorded in WORK_HANDOFF_STATUS.md once verified.
