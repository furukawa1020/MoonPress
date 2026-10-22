///|
fn is_revision_command(command : String) -> Bool {
  [
    "history-enable", "history", "checkpoint", "revision", "restore-revision", "compare-revision",
  ].contains(command)
}

///|
fn revision_required(command : String) -> Int {
  match command {
    "history-enable" => 3
    "checkpoint" | "compare-revision" => 5
    "restore-revision" => 6
    _ => 4
  }
}

///|
fn revision_usage(command : String) -> String {
  let suffix = match command {
    "history-enable" => " [--json]"
    "history" => " <article.md> [--json]"
    "checkpoint" => " <article.md> <expected-digest> [--json]"
    "revision" => " <revision-id> [--json]"
    "compare-revision" => " <article.md> <revision-id> [--json]"
    _ => " <article.md> <expected-current-digest> <revision-id> [--json]"
  }
  "Usage: moonpress " + command + " <site-directory>" + suffix
}

///|
fn revision_run(args : Array[String]) -> Json raise {
  match args[1] {
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
