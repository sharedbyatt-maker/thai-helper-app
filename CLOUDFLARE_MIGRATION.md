Cloudflare Pages configuration
Repository: sharedbyatt-maker/thai-helper-app (keep PRIVATE)
Initial deployment branch: codex/cloudflare-migration
Framework preset: None
Root directory: / (repository root)
Build command: bash scripts/build_cloudflare.sh
Output directory: flutter_app/build/web
Environment variables:
  NODE_VERSION=24
  SKIP_DEPENDENCY_INSTALL=1
  RATES_API=https://bahtzay-api-staging.sharedbyatt.workers.dev
Production URL verified: https://thai-helper-app.pages.dev/
PUBLIC_APP_URL defaults to that stable production URL. Preview metadata points to production.
After validation and merge, change the Cloudflare production branch to master for future updates.
No API token, DB, Functions, Worker or payment setup is required for the frontend.
The Pages frontend and notification retry workflow use the validated Cloudflare API Worker and its D1 database. Publish rates in the Cloudflare Access-protected admin Worker at https://bahtzay-admin-staging.sharedbyatt.workers.dev/admin/index.html. The Workers retain their original staging names. The historical Sites database is separate. Revert the API cutover commit to restore the old default and rebuild the web app.
