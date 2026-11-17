ALTER TABLE projects ADD COLUMN tagline TEXT NOT NULL DEFAULT '';
--> statement-breakpoint
ALTER TABLE documents ADD COLUMN excerpt TEXT NOT NULL DEFAULT '';
--> statement-breakpoint
ALTER TABLE documents ADD COLUMN live_excerpt TEXT;
--> statement-breakpoint
ALTER TABLE documents ADD COLUMN trashed TEXT;
--> statement-breakpoint
ALTER TABLE documents ADD COLUMN modified TEXT;
--> statement-breakpoint
ALTER TABLE documents ADD COLUMN live_modified TEXT;
--> statement-breakpoint
ALTER TABLE documents ADD COLUMN live_version INTEGER;
--> statement-breakpoint
UPDATE documents SET modified=published, live_modified=published,
  live_version=CASE WHEN version=1 THEN version END WHERE published IS NOT NULL;
