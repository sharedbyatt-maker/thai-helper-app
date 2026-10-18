CREATE TABLE `notification_events` (
	`revision` integer PRIMARY KEY NOT NULL,
	`request_id` text NOT NULL,
	`payload` text NOT NULL,
	`kind` text NOT NULL,
	`created_at` integer NOT NULL,
	`expires_at` integer NOT NULL
);
--> statement-breakpoint
CREATE TABLE `push_config` (
	`id` integer PRIMARY KEY NOT NULL,
	`public_key` text NOT NULL,
	`sealed` text NOT NULL
);
--> statement-breakpoint
CREATE TABLE `push_outbox` (
	`id` text PRIMARY KEY NOT NULL,
	`subscriber_id` text NOT NULL,
	`subscription_version` integer NOT NULL,
	`revision` integer NOT NULL,
	`status` integer DEFAULT 0 NOT NULL,
	`attempts` integer DEFAULT 0 NOT NULL,
	`next_attempt` integer DEFAULT 0 NOT NULL,
	`last_error` text DEFAULT '' NOT NULL
);
--> statement-breakpoint
CREATE TABLE `push_subscribers` (
	`id` text PRIMARY KEY NOT NULL,
	`endpoint` text NOT NULL,
	`keys_json` text NOT NULL,
	`manage_hash` text NOT NULL,
	`active` integer DEFAULT 1 NOT NULL,
	`version` integer DEFAULT 1 NOT NULL,
	`start_revision` integer NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL
);
