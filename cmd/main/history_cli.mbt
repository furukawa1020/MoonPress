///|
fn is_revision_command(command : String) -> Bool {
  if is_access_command(command) {
    return true
  }
  if is_trash_command(command) {
    return true
  }
  [
    "wxr-inspect", "wxr-import", "wxr-export", "post-schedule", "post-categories",
    "post-kind", "history-enable", "history", "checkpoint", "revision", "restore-revision",
    "compare-revision",
  ].contains(command)
}

///|
fn revision_required(command : String) -> Int {
  if is_access_command(command) {
    return access_required(command)
  }
  if is_trash_command(command) {
    return trash_required(command)
  }
  match command {
    "wxr-inspect" => 3
    "wxr-import" => 7
    "post-schedule" | "post-categories" | "post-kind" => 6
    "history-enable" => 3
    "checkpoint" | "compare-revision" => 5
    "restore-revision" => 6
    _ => 4
  }
}

///|
fn revision_usage(command : String) -> String {
  if is_access_command(command) {
    return access_usage(command)
  }
  if is_trash_command(command) {
    return trash_usage(command)
  }
  let suffix = match command {
    "wxr-inspect" => " [--json]"
    "wxr-import" =>
      " <wxr-file> <inspected-digest> <post-id> <new-stem> [--json]"
    "wxr-export" => " <source-site-base-url> [--json]"
    "post-schedule" =>
      " <article.md> <expected-digest> <UTC-timestamp|empty-string> [--json]"
    "post-categories" =>
      " <article.md> <expected-digest> <newline-separated-categories> [--json]"
    "post-kind" => " <article.md> <expected-digest> <post|page> [--json]"
    "history-enable" => " [--json]"
    "history" => " <article.md> [--json]"
    "checkpoint" => " <article.md> <expected-digest> [--json]"
    "revision" => " <revision-id> [--json]"
    "compare-revision" => " <article.md> <revision-id> [--json]"
    _ => " <article.md> <expected-current-digest> <revision-id> [--json]"
  }
  "Usage: moonpress " +
  command +
  (if command == "wxr-inspect" { " <wxr-file>" } else { " <site-directory>" }) +
  suffix
}

///|
fn revision_run(args : Array[String]) -> Json raise {
  if is_access_command(args[1]) {
    return access_run(args)
  }
  if is_trash_command(args[1]) {
    return trash_run(args)
  }
  match args[1] {
    "wxr-inspect" => @lib.inspect_wordpress_file(args[2]).to_json()
    "wxr-import" =>
      @lib.import_wordpress_file(args[2], args[3], args[4], args[5], args[6]).to_json()
    "wxr-export" => @lib.export_wordpress(args[2], args[3]).to_json()
    "post-schedule" =>
      @lib.save_post_schedule(args[2], args[3], args[4], args[5]).to_json()
    "post-categories" =>
      @lib.save_post_categories(args[2], args[3], args[4], args[5]).to_json()
    "post-kind" =>
      @lib.save_post_kind(args[2], args[3], args[4], args[5]).to_json()
    "history-enable" => @lib.enable_post_history(args[2]).to_json()
    "history" => @lib.list_post_revisions(args[2], args[3]).to_json()
    "checkpoint" => @lib.checkpoint_post(args[2], args[3], args[4]).to_json()
    "revision" => @lib.read_post_revision(args[2], args[3]).to_json()
    "compare-revision" =>
      @lib.compare_post_revision(args[2], args[3], args[4]).to_json()
    _ =>
      @lib.restore_post_revision(args[2], args[3], args[4], args[5]).to_json()
  }
}
