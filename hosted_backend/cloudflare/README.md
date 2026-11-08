# BahtZay Cloudflare staging

Two Workers share one new D1 database. The private admin Worker serves the
existing dashboard. The public API Worker serves rates, history, push and the
Telegram webhook. Keep the existing Cloudflare Pages frontend pointed at its
current production API until cutover. Worker hostnames are assigned by your
Cloudflare account.

## Configure and stage

1. In your Cloudflare account enable Workers and Zero Trust Access, then create
   a **new** D1 database named `bahtzay`. Copy the example Wrangler configs
   to `wrangler.admin.jsonc` and `wrangler.public.jsonc` in this directory.
   Fill in the same D1 ID in both, the actual public Worker origin, and the
   exact owner email. The filled configurations are gitignored.
2. From this directory, run the following with authenticated Wrangler.

   ```sh
   node build-admin.mjs
   npx wrangler d1 migrations apply bahtzay --remote --config wrangler.public.jsonc
   npx wrangler deploy --config wrangler.public.jsonc
   npx wrangler deploy --config wrangler.admin.jsonc
   npx wrangler secret put TELEGRAM_CONFIG_KEY --config wrangler.public.jsonc
   npx wrangler secret put TELEGRAM_CONFIG_KEY --config wrangler.admin.jsonc
   ```

   Use the **same** 64-hex encryption secret for both Workers. Use the old
   key only when migrating encrypted settings or the VAPID key. For a fresh
   database, generate a new secret privately. Do not commit any secrets.
3. In the admin Worker's Access tab, protect its production `workers.dev`
   URL. Configure an Allow policy for the owner email only. Keep the public
   Worker publicly reachable. The admin Worker deliberately serves its small
   dashboard bundle from its code so Access identity is available to the
   Worker. It denies every request until Access authenticates the owner.
4. Verify anonymous admin access is denied and the owner can load the
   dashboard. Verify the public health endpoint. Use a separate test bot and
   test device for staging notifications. Avoid re-registering the production
   Telegram bot before cutover, because that replaces its current webhook.

## Data and cutover

- An empty D1 is a clean start. To retain private data, obtain an authorized
  export from the old Sites project. Restore into the **new** D1 only. Use
  the schema/migration state matching the export, and do not apply the same
  migrations a second time. The old ChatGPT owner row uses a different
  identity namespace. Remove only that row from the new database after
  validating the import and before first owner login.
- Retaining push and Telegram settings requires the old encryption key
  alongside the data. Verify decryption and delivery before directing traffic
  to the new API. Avoid replaying queued notifications from the old environment.
- Confirm rates, history, owner-only draft/publish, notification preview and a
  private test send. Then set the existing Pages project's production
  `RATES_API` to the public Worker origin and redeploy. Update the production
  notification retry endpoint and Telegram webhook, if used. Keep the old
  endpoint available until validation completes so the Pages API setting can
  be rolled back.
