CREATE TABLE `alert_outbox` (
	`id` text PRIMARY KEY NOT NULL,
	`chat_id` text NOT NULL,
	`subscription_version` integer NOT NULL,
	`revision` integer NOT NULL,
	`payload` text NOT NULL,
	`status` integer DEFAULT 0 NOT NULL,
	`attempts` integer DEFAULT 0 NOT NULL,
	`next_attempt` integer DEFAULT 0 NOT NULL
);
--> statement-breakpoint
CREATE TABLE `alert_subscribers` (
	`chat_id` text PRIMARY KEY NOT NULL,
	`bot` text NOT NULL,
	`direction` text NOT NULL,
	`mode` text NOT NULL,
	`threshold` integer,
	`active` integer DEFAULT 1 NOT NULL,
	`version` integer DEFAULT 1 NOT NULL,
	`evaluated_revision` integer DEFAULT 0 NOT NULL,
	`last_signature` text DEFAULT '' NOT NULL,
	`created_at` integer NOT NULL
);
