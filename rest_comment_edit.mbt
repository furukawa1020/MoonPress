///|
fn native_comment_edit(
  input : String,
  content : AuthoringDirectory,
  id : Int,
  expected : String?,
  fields : Map[String, Json],
) -> RestResponse raise {
  let log = match comment_open(input, content) {
    Some(log) => log
    None => return rest_error(404, "moonpress_comment_missing")
  }
  defer directory_close(log.fd)
  log.lock()
  let state = comment_replay(log)
  if id < 1 || id > state.rows.length() {
    return rest_error(404, "moonpress_comment_missing")
  }
  let current = state.rows[id - 1]
  if rest_precondition(expected, current.revision) is Some(error) {
    return error
  }
  if current.comment.status == "trash" {
    return rest_error(409, "moonpress_comment_trashed")
  }
  let text = try {
    let text = match fields.get("content") {
      None => current.comment.content
      Some(String(text)) =>
        text.replace_all(old="\r\n", new="\n").replace_all(old="\r", new="\n")
      _ => raise InvalidInput("Expected text")
    }
    comment_text(text, 8192)
    text
  } catch {
    _ => return rest_error(400, "rest_invalid_param")
  }
  let label = try {
    let label = match fields.get("author_name") {
      None => current.comment.author_name
      Some(String(value)) => value.trim().to_owned()
      _ => raise InvalidInput("Expected public name")
    }
    comment_text(label, 80)
    if label.any(c => c.is_control()) {
      raise InvalidInput("Invalid name")
    }
    label
  } catch {
    _ => return rest_error(400, "rest_invalid_param")
  }
  let status = match fields.get("status") {
    None => current.comment.status
    Some(String(value)) if ["hold", "approved", "spam"].contains(value) => value
    _ => return rest_error(400, "rest_invalid_param")
  }
  let next = { ..current.comment, content: text, author_name: label, status, }
  if next == current.comment {
    return rest_ok(
      native_comment_value(current, true),
      etag=Some(current.revision),
    )
  }
  let row = match comment_append(log, state, next, "edit") {
    Some(row) => row
    None => return rest_error(409, "moonpress_comment_storage_full")
  }
  rest_ok(native_comment_value(row, true), etag=Some(row.revision))
}
