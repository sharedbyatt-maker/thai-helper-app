CREATE TABLE `revision_trash` (
	`id` integer PRIMARY KEY NOT NULL,
	`payload` text NOT NULL,
	`published_at` text NOT NULL,
	`deleted_at` text NOT NULL,
	`request_id` text NOT NULL
);
