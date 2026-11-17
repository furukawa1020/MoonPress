CREATE TABLE projects (
  slug TEXT PRIMARY KEY,
  owner TEXT NOT NULL,
  title TEXT NOT NULL,
  created TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
--> statement-breakpoint
CREATE INDEX projects_owner ON projects(owner);
--> statement-breakpoint
CREATE TABLE documents (
  project TEXT NOT NULL REFERENCES projects(slug),
  slug TEXT NOT NULL,
  title TEXT NOT NULL,
  kind TEXT NOT NULL,
  body TEXT NOT NULL,
  version INTEGER NOT NULL DEFAULT 1,
  live_title TEXT,
  live_kind TEXT,
  live_body TEXT,
  published TEXT,
  PRIMARY KEY (project, slug)
);
