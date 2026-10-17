CREATE TABLE `history_replacements` (
	`id` text PRIMARY KEY NOT NULL,
	`request_id` text NOT NULL,
	`created_at` text NOT NULL,
	`applied_at` text,
	`backup_json` text NOT NULL,
	`summary_json` text NOT NULL
);
