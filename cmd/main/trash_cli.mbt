///|
fn is_trash_command(command : String) -> Bool {
  ["trash-post", "trash-list", "trash-read", "trash-restore", "trash-purge"].contains(
    command,
  )
}

///|
fn trash_required(command : String) -> Int {
  match command {
    "trash-purge" => 6
    "trash-list" => 3
    "trash-read" => 4
    _ => 5
  }
}

///|
fn trash_usage(command : String) -> String {
  let suffix = match command {
    "trash-purge" => " <trash-id> <expected-record-digest> confirm-permanent"
    "trash-list" => ""
    "trash-read" => " <trash-id>"
    "trash-post" => " <article.md> <expected-current-digest>"
    _ => " <trash-id> <expected-record-digest>"
  }
  "Usage: moonpress " + command + " <site-directory>" + suffix + " [--json]"
}

///|
fn trash_run(args : Array[String]) -> Json raise {
  match args[1] {
    "trash-purge" =>
      @lib.purge_trashed_post(
        args[2],
        args[3],
        args[4],
        args[5] == "confirm-permanent",
      ).to_json()
    "trash-list" => @lib.list_trashed_posts(args[2]).to_json()
    "trash-read" => @lib.read_trashed_post(args[2], args[3]).to_json()
    "trash-post" => @lib.trash_post(args[2], args[3], args[4]).to_json()
    _ => @lib.restore_trashed_post(args[2], args[3], args[4]).to_json()
  }
}
