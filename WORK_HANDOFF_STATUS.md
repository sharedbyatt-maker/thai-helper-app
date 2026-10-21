# ဘတ်ဈေး — verified work checkpoint

Updated 2026-10-21 (Bangkok). Read this before changing or deploying anything. Re-check live workflow status when resuming; a merge alone is not a deployment.

## Preserved requirements
Approved Concept A pixels and the name ဘတ်ဈေး remain. Real rate data, conversion math, local budget/records, backup schema, owner authentication and Telegram behavior are unchanged. Tabs remain ဘတ်ဈေး → ငွေတွက် → ငွေစာရင်း → မှတ်တမ်း. User authorized PRs, passing CI, merge and deployment. Do not publish fake rates/campaigns, send test notifications, activate ads, add paid services or reset owner/secrets.

## Completed source and CI
- PR33: https://github.com/sharedbyatt-maker/thai-helper-app/pull/33
  - Merged f1d52d02671cda97d8c1bb6bafb377780952d66b after backend/Flutter CI passed.
  - Authoritative Emergency OFF ignores invalid/stale browser forms; private saved ad draft, CAS, atomic published history/rollback; multi-placement editing; actual private banner preview; explicit UTC campaign dates.
  - Additive 0007/0008 migrations; original migrations/snapshots unchanged. 68 backend + 3 Admin DOM tests pass.
- PR34: https://github.com/sharedbyatt-maker/thai-helper-app/pull/34
  - Merged e4877d9059e1d00cf092d2662c1ceaf7ae391015.
  - Final PR head 3c4ef6a2bbcab6be615dbdecfa8f1eea5935e465: backend, Flutter, Android debug and iOS Simulator CI all passed.
  - Flutter analyze clean; all 115 local/CI Flutter tests pass. Branding/push checks also pass.
  - Sponsors refresh within 60 seconds plus request time, refresh on resume, expire locally and fail closed. Late requests cannot replace current language/configuration. No personal finance data is sent to sponsor API.
  - Android/iOS runner sources committed; ID io.github.sharedbyattmaker.bahtzay; display name ဘတ်ဈေး. Production Android release no longer silently uses debug signing.
  - Native combined backup can select JSON (2 MB bound) and share a named JSON file with iPad anchor. Explicit paste/copy fallback and restore preview/confirmation remain. Web/native storage sandboxes are separate; no automatic data migration/upload.
  - Native icons/launch image exported by scripts/prepare_native_icons.py from hash-verified approved pixels. Android preserves alpha. iOS composites transparent edges onto green sampled from the approved source; every fully opaque source pixel stays identical at 1024.

## Existing backend — actually deployed
- Site: https://bahtzay-rates.muddyhinny2048.chatgpt.site
- Admin: https://bahtzay-rates.muddyhinny2048.chatgpt.site/admin/index.html
- Exact Sites project: appgprj_6ad0c8fbbaac81919650d456128efe4e
- Audience public, Admin owner-authorized on server. Preserve audience and owner.
- D1 binding DB, R2 unused. Sites version 21 deployed successfully.
- Source fde149544b3d09669349e02a98c838f9405341c8; deployment appgdep_6ad89169f78c8191b91c0456beb2fee1.
- Live D1 overview confirms ad_configuration/ad_draft/ad_history plus all previous tables.
- Live app successfully reads original 745 / 722 quotes (observed Oct19 12:07 Bangkok) and correctly displays stale status. No rates republished.
- After live app loaded the public ads route, live ad_configuration row v0 confirmed all switches false and sponsors empty. No campaign was published or enabled.
- Executor direct HTTP requests return 403; do not confuse that with the public app failing. Browser preview owner tools required sign-in, so production owner clicks were not exercised. Server/API/DOM tests cover those operations without production writes.

## Native build evidence
https://github.com/sharedbyatt-maker/thai-helper-app/actions/runs/39584910632 succeeded for final PR head, with both artifacts:
- bahtzay-android-debug-preview: artifact 12338628925 (debug APK).
- bahtzay-ios-simulator-preview: artifact 12338334553 (Simulator .app).
Artifacts expire 2026-10-28; rerun workflow if needed. See NATIVE_PREVIEW_HANDOFF.md.

These are compile proofs, not physical-device/store tests. iOS Simulator .app cannot be installed on an ordinary iPhone. No developer accounts, production signing, store submission, native push or real AdMob/AdSense delivery is claimed. Direct sponsor controls remain default OFF. Avoid interstitial/app-open/rewarded ads or obstructing calculator/budget.

## Public web deployment checkpoint
- PWA: https://sharedbyatt-maker.github.io/thai-helper-app/
- Native/app code release target: e4877d9059e1d00cf092d2662c1ceaf7ae391015.
- Authoritative publish run: https://github.com/sharedbyatt-maker/thai-helper-app/actions/runs/39585673789
- Master checks: https://github.com/sharedbyatt-maker/thai-helper-app/actions/runs/39585673955
- Master native proofs: https://github.com/sharedbyatt-maker/thai-helper-app/actions/runs/39585673890
- Publish run 39585673789 succeeded; Pages run 39585994131 succeeded for gh-pages d82d61d5c89b5b700c44e98310da2b27dc9d033e (deploy e4877d9059e1d00cf092d2662c1ceaf7ae391015).
- Live browser verification at 17:39–17:40 Bangkok confirmed new main.dart.js/bootstrap version d6fedc286b0869f7 (previous 04563a45cb1a5e18), approved icon references, original header logo/name, original 745/722 quotes with honest stale status, all four tabs in order and complete-backup picker/preview controls. No record/backup export or restore was performed.
- Master app checks 39585673955 succeeded. Native PR build proof above is complete; master native run link is available separately. GitHub Pages and Sites backend are independently verified deployments.

## Workspace continuity
A transient workspace reset lost an earlier unpushed attempt; changes were recovered from remote master, re-tested and committed. Do not depend on old scratch paths or print/transmit binary/base64 assets through chat. No new repository or Site was created. Keep credentials only in session memory and the source helper's hidden stdin. Preserve the unrelated working-tree deletion backend/.venv/bin/python3; do not include it in task commits.
