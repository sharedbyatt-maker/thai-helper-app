CREATE TABLE `ad_draft` (
	`id` integer PRIMARY KEY NOT NULL,
	`version` integer DEFAULT 0 NOT NULL,
	`payload` text NOT NULL,
	`updated_at` text NOT NULL
);
--> statement-breakpoint
CREATE TABLE `ad_history` (
	`version` integer PRIMARY KEY NOT NULL,
	`payload` text NOT NULL,
	`updated_at` text NOT NULL
);

--> statement-breakpoint
CREATE TRIGGER ad_history_on_update AFTER UPDATE ON ad_configuration
BEGIN
 INSERT OR IGNORE INTO ad_history(version,payload,updated_at)
 VALUES(OLD.version,OLD.payload,OLD.updated_at),(NEW.version,NEW.payload,NEW.updated_at);
END;
