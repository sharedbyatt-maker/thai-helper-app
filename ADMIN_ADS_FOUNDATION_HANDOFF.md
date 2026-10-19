# Admin Control Center and Advertising Foundation

Status: feature branch `feat/admin-control-center-ads-foundation`, PR #31. Do not treat unmerged or undeployed work as live.

## Scope
- Existing owner-only ChatGPT Sites admin remains the authentication authority.
- Existing THB/MMK draft/preview/publish, revision history, Telegram, announcements and APK/Play settings retain their IDs and behavior.
- New responsive admin sections: Overview, Exchange Rates, Ads & Sponsors, Notifications, Publication History, App & System.
- Persistent D1 owner ad configuration: independent from exchange-rate drafts; new public API `GET /api/v2/ads`, owner routes `GET/PUT /api/admin/ads`.
- New Flutter `SponsorBanner` on Home (after the chart/tools) and History (at the bottom). It is hidden by default or on errors; no personal finance information is sent to the ad endpoint.
- Explicit master toggle, platform toggles, ad format and placement flags, sponsor switches, schedules, language filter, priority and emergency OFF.

## Important safety restrictions
- **Advertising is OFF by default.**
- **No AdMob or AdSense SDK is added yet**, no real ad unit IDs, no account login and no false revenue/analytics claims. Google account approval, consent flows and native builds must precede production mobile ads.
- Sponsor media/destination URLs require HTTPS and cannot contain URL credentials or localhost; inline HTML/JavaScript creatives are not accepted.
- Public API returns only effective active sponsor information and nonsecret switches; owner endpoint alone permits writes, with stale-version rejection.
- This is a platform-independent control-plane and direct-sponsor viewer foundation, not complete network ad monetization.
- External sponsor images load from the sponsor URL when enabled, which may send the visitor's IP address to that image host. Before activating sponsor campaigns, review privacy disclosures, choose trusted images or build a safe same-origin media hosting/proxy solution.
- Sponsor placements are intentionally limited to Home/History in the Flutter app even though future platform/placement flags are stored. Calculator and personal budget are ad-free by default.
- Existing D1 migrations must run before calling new routes; deploy through authorized ChatGPT Sites workflow. **GitHub merge alone does not update the separately hosted Sites backend.**

## Release gates
1. Run Python/backend admin tests, hosted backend `node --test`, new ads API tests, JS DOM admin UI tests and Flutter analyze/test/build.
2. Review D1 migration with Sites deployment tooling. Apply migration before serving the new Ads admin UI.
3. Merge only passing PR and verify existing web PWA GitHub Pages deploy.
4. Deploy hosted backend to ChatGPT Sites only with access and supported deployment workflow. Verify `/api/v2/ads` and owner admin controls after deploy.
5. On Android/iOS, create native Flutter platform projects and debug builds in appropriate SDK environments. Native release signing, Google Play / Apple Developer enrollment, ad account IDs and production consent are pending separate permissions/accounts.

## Future implementation
- Production-ready Android and iOS Flutter projects with stable app IDs, deep linking and safe transfer of existing local browser records.
- AdMob mobile SDK and consent (UMP; iOS ATT when required); AdSense/Web provider with approvals.
- Creative asset upload/hosting, validation and moderation, trusted-media delivery, campaign click/impression reporting with privacy protections.
- Sponsor billing/revenue reporting and role-based admin audit logs, if needed.

Never represent placeholder toggles as working AdMob ad delivery.
