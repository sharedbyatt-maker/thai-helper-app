# ဘတ်ဈေး work checkpoint

## Scope and invariants
Continue on latest master. Keep approved Concept A logo, app name, actual rates/calculations, user money data, backup format, owner authorization and Telegram behavior. Four tabs stay ဘတ်ဈေး → ငွေတွက် → ငွေစာရင်း → မှတ်တမ်း. User authorized PR, CI, merge and deployment. Never publish dummy rates or enable production ads for testing.

## Current work (2026-10-21, Bangkok)
- Base: b73767e5d2e89f2d4876912a1f00915125d62b7d (PR32).
- Backend: independent authoritative Emergency OFF, server-side private ad draft, recoverable published history/rollback, multi-placement editor, actual owner banner preview, explicit UTC campaign fields.
- Additive migrations: existing 0007 ads configuration and new 0008 draft/history with atomic audit trigger. Historical migrations unchanged.
- Local Node: 68 backend tests + 3 Admin tests pass. Deployment not yet performed at this checkpoint.
- Remaining: bounded sponsor refresh/expiry/resume in app, Flutter/remote CI, merge, deploy existing backend, verify native foundations/builds.

## Deployment identities
- Public PWA: https://sharedbyatt-maker.github.io/thai-helper-app/
- Existing backend: https://bahtzay-rates.muddyhinny2048.chatgpt.site
- Sites project: appgprj_6ad0c8fbbaac81919650d456128efe4e
- Existing audience: public; owner-only Admin enforced by server. Preserve audience.
- D1 binding: DB; R2 unused. Live Site version last read: 20; source 728800f9f5c74ebc2bcd60dd116f91c73b31aab6. No claim that GitHub source is already deployed.
- Native runners/builds and real ad SDK are not yet complete. No store releases or real ad delivery claimed.

## Continuity
Transient workspace reset lost previous unpushed edits; restored against remote master and re-tested. Do not use old scratch SDK paths. Keep credentials out of Git and logs. The unrelated deletion backend/.venv/bin/python3 must not be included in task commits.
