CREATE TABLE android_push_delivery (
  revision INTEGER PRIMARY KEY,
  attempts INTEGER NOT NULL DEFAULT 0,
  retry_at INTEGER NOT NULL DEFAULT 0,
  sent INTEGER NOT NULL DEFAULT 0,
  enabled_at INTEGER
);
