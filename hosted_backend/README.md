# ဘတ်ဈေး hosted rates backend

This Site hosts the THB/MMK public reference sheet and owner administration.
The Flutter client is maintained at https://github.com/sharedbyatt-maker/thai-helper-app .

## Daily use

1. Open `/admin/index.html` and sign in with ChatGPT.
2. Use the ChatGPT account that owns this Site. On the first authenticated visit its verified email is checked against the owner returned by native Sites access settings, then its Site-specific user ID is pinned atomically in D1. Subsequent sign-ins authorize only that pinned ID. No password or activation code is required.
3. Add separate quotes for THB→MMK and MMK→THB; check source, fees, payout method, observation and expiry times.
4. Save Draft, Preview, then Publish. Drafts are private; public users see only published immutable revisions. Old revisions can be restored to a draft, checked, and published again.
5. The public app refreshes within about a minute. Expired quotes remain labeled as expired and cannot be selected for calculation.

No actual exchange rates are seeded. The owner must verify and publish real rates.

## Hosting and security

- Sites provisions a durable Cloudflare D1 database (`DB` binding); process restarts and app deployments do not erase rates.
- Public routes: `/api/v2/rates`, `/api/rates`, `/api/health`. Only public sheet endpoints allow cross-origin reads. Public data contains the owner's source descriptions, never user transaction records.
- Dispatch-owned ChatGPT authentication supplies the stable Site user ID. Every admin request authorizes against D1 `admin_owner`; other signed-in accounts are denied. Mutations require a same-origin `Origin` and a custom request header.
- Production runtime secret: `ADMIN_OWNER_EMAIL`, set from the trusted native Sites owner record, never from a public request. It can bootstrap only the initial owner ID; after that even a matching email on a different user ID cannot claim ownership. No first-visitor takeover is possible. Recovery requires the Site owner to replace the D1 owner entry through trusted maintenance; there is no public account-reset endpoint.
- D1 schema migrations are append-only. No schema changes run during requests. The draft seed uses an idempotent data insert after authentication.
- Draft updates and publishing compare version numbers. D1 batches publish plus version advancement atomically; stale tabs receive 409.
- Monthly personal records stay in the user's browser. They are not uploaded here.

## Validation and maintenance

`node --test test/api.test.mjs` exercises the actual request handler against SQLite through a D1-compatible adapter: anonymous access, trusted-owner bootstrap, owner isolation, draft visibility, stale writes, publish/restore, preserved state, origin checks, source validation, expired publication and body limits.

Use the Sites skill to install, build and publish. `npm run db:generate` generates migrations from `db/schema.ts`. Runtime secrets belong in native Site settings, never `.openai/hosting.json`. The source repository retains the full build integration and lockfile.

This deployment does not create a paid Render service. Direct Cloudflare Workers Free/D1 is a possible later migration subject to Cloudflare quotas and a Cloudflare account; this Site is provisioned through ChatGPT Sites, whose account terms and availability apply.

## Public rate trend

`/api/v2/history` exposes only already-published rate observations from the last 30 Bangkok calendar days (up to the latest 400 revisions). The chart separates quote ID, direction, source name/link and payout method; it keeps the last published observation for each source/day and does not fill missing days. Rates are MMK per THB, excluding fees. At least two observed days are needed to draw a trend. Low/high and percentage change describe the available observations, not an inferred market-wide price. Draft and admin data are never included.
