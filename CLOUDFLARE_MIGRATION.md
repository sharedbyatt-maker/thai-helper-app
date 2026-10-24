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
  RATES_API=https://bahtzay-rates.muddyhinny2048.chatgpt.site
Set PUBLIC_APP_URL to the exact production pages.dev URL once Cloudflare assigns it.
No API token, DB, Functions, Worker or payment setup is required for the frontend.
The existing Backend/Admin remains on Sites. Push origin allowlist and server-generated links must be updated after the exact production URL is known. Do not send notifications before that follow-up deployment and checks.
