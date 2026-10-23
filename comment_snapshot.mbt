///|
fn comment_snapshot_at(
  input : String,
  content : AuthoringDirectory,
) -> CommentState raise {
  match comment_open(input, content) {
    Some(log) => {
      defer directory_close(log.fd)
      log.lock()
      comment_replay(log)
    }
    None => { sequence: 0, revision: "absent", rows: [], bytes: 0, }
  }
}

///|
fn native_comment_summary_path(path : String) -> Bool {
  native_parts(path) == ["comments", "summary"]
}

///|
fn native_comment_summary(
  input : String,
  content : AuthoringDirectory,
  principal : AccessPrincipal,
  query : Map[String, String],
) -> RestResponse raise {
  if !role_capabilities(principal.role).contains("moderate_comments") {
    return rest_error(403, "moonpress_cannot_moderate")
  }
  if !query.is_empty() {
    return rest_error(400, "rest_invalid_param")
  }
  let state = comment_snapshot_at(input, content)
  let counts : Map[String, Int] = Map([
    ("hold", 0),
    ("approved", 0),
    ("spam", 0),
    ("trash", 0),
  ])
  for row in state.rows {
    counts[row.comment.status] = counts[row.comment.status] + 1
  }
  rest_ok({
    "counts": counts.to_json(),
    "total": state.rows.length().to_json(),
    "events": state.sequence.to_json(),
    "event_limit": (4096 : Int).to_json(),
    "bytes": state.bytes.to_json(),
    "byte_limit": (16777216 : Int).to_json(),
    "comment_limit": (1024 : Int).to_json(),
  })
}

///|
fn comment_snapshot(input : String) -> CommentState raise {
  let content = open_authoring_subdirectory(input, "content")
  defer directory_close(content.fd)
  content.lock()
  comment_snapshot_at(input, content)
}
