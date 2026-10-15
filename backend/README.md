# Currency publishing backend

See the root [README](../README.md) for setup, password configuration, persistent storage, deployment and daily publishing.

Public endpoints: `GET /api/health`, `GET /api/v2/rates` (`/api/rates` alias).

Owner dashboard: `/admin`.

Admin endpoints: `POST /api/admin/login`, `GET /api/admin/state`, `PUT /api/admin/draft`, `POST /api/admin/publish`, `POST /api/admin/restore`, `POST /api/admin/logout`.

All admin mutations require the same-origin dashboard's `X-Admin-Request` header; authenticated mutations additionally require its CSRF token. Draft save/publish/restore require `expected_version` and return HTTP 409 when another edit has changed the draft.

The public payload is schema version 2. Legacy provider comparison/click/statistics endpoints are retired. There is no customer-record API; personal records remain device-local.
