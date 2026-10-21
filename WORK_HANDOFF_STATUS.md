# ဘတ်ဈေး work checkpoint

## Scope and invariants
Continue on latest master. Keep approved Concept A logo, app name, actual rates/calculations, user money data, backup format, owner authorization and Telegram behavior. Four tabs stay ဘတ်ဈေး → ငွေတွက် → ငွေစာရင်း → မှတ်တမ်း. User authorized PR, CI, merge and deployment. Never publish dummy rates or enable production ads for testing.

## Current work (2026-10-21, Bangkok)
- Base: b73767e5d2e89f2d4876912a1f00915125d62b7d (PR32).
- Backend: independent authoritative Emergency OFF, server-side private ad draft, recoverable published history/rollback, multi-placement editor, actual owner banner preview, explicit UTC campaign fields.
- Additive migrations: existing 0007 ads configuration and new 0008 draft/history with atomic audit trigger. Historical migrations unchanged.
- Local Node: 68 backend tests + 3 Admin tests pass. Deployment not yet performed at this checkpoint.
- PR33 merged as f1d52d02671cda97d8c1bb6bafb377780952d66b after backend + Flutter CI success.
- Existing backend deployed successfully as Sites version 21, source fde149544b3d09669349e02a98c838f9405341c8, deployment appgdep_6ad89169f78c8191b91c0456beb2fee1. Live D1 overview confirms ad_configuration/ad_draft/ad_history. All prior tables remain. Direct HTTP verification from executor returns 403; do not claim that route was verified via executor. Owner browser preview requires sign-in; no production fake rates or ad campaign was published.
- App now bounds sponsor visibility to 60 seconds, refreshes on resume, hides on expiry/failure and rejects late requests. Six sponsor widget checks pass.
- Committed native runner sources use io.github.sharedbyattmaker.bahtzay and ဘတ်ဈေး. Icons/launch image generated from hash-verified approved pixels by scripts/prepare_native_icons.py before builds. Production Android release no longer silently uses debug signing.
- Native combined backup adds selected-file import (2 MB bound) and user-initiated JSON file sharing with an iPad anchor. Backup schemas and storage logic unchanged. Explicit paste/copy fallback remains.
- Flutter analyze clean and all 115 local Flutter tests pass. Native CI proof builds are still pending at this checkpoint. No store signing/publication or real ad SDK/delivery claimed.
- Remaining: app/native PR CI, debug APK and iOS Simulator builds; merge/deploy PWA; verify final live version and record exact outcomes.

## Deployment identities
- Public PWA: https://sharedbyatt-maker.github.io/thai-helper-app/
- Existing backend: https://bahtzay-rates.muddyhinny2048.chatgpt.site
- Sites project: appgprj_6ad0c8fbbaac81919650d456128efe4e
- Existing audience: public; owner-only Admin enforced by server. Preserve audience.
- D1 binding: DB; R2 unused. Live Site version last read: 20; source 728800f9f5c74ebc2bcd60dd116f91c73b31aab6. No claim that GitHub source is already deployed.
- Native runners/builds and real ad SDK are not yet complete. No store releases or real ad delivery claimed.

## Continuity
Transient workspace reset lost previous unpushed edits; restored against remote master and re-tested. Do not use old scratch SDK paths. Keep credentials out of Git and logs. The unrelated deletion backend/.venv/bin/python3 must not be included in task commits.
