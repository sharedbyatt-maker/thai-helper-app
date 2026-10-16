CREATE TABLE `telegram_pending` (
	`id` text PRIMARY KEY NOT NULL,
	`owner_id` text NOT NULL,
	`payload` text NOT NULL,
	`expires` integer NOT NULL,
	`used` integer DEFAULT 0 NOT NULL
);
--> statement-breakpoint
CREATE TABLE `telegram_receipts` (
	`id` text PRIMARY KEY NOT NULL,
	`request_id` text NOT NULL,
	`revision` integer,
	`response` text NOT NULL,
	`created_at` integer NOT NULL
);
--> statement-breakpoint
CREATE TABLE `telegram_session` (
	`id` integer PRIMARY KEY NOT NULL,
	`source` text NOT NULL
);
--> statement-breakpoint
CREATE TABLE `telegram_settings` (
	`id` integer PRIMARY KEY NOT NULL,
	`sealed` text NOT NULL,
	`username` text NOT NULL,
	`owner_id` text,
	`pair_hash` text,
	`pair_until` integer,
	`generation` integer DEFAULT 0 NOT NULL
);
