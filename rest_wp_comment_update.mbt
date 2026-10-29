///|
fn wp_comment_row(
  input : String,
  content : AuthoringDirectory,
  id : Int,
) -> CommentRow? raise {
  let log = match comment_open(input, content) {
    Some(log) => log
    None => return None
  }
  defer directory_close(log.fd)
  log.lock()
  let state = comment_replay(log)
  if id < 1 || id > state.rows.length() {
    None
  } else {
    Some(state.rows[id - 1])
  }
}

///|
fn wp_comment_result(
  input : String,
  content : AuthoringDirectory,
  result : RestResponse,
  base : String,
) -> RestResponse raise {
  if result.code != 200 {
    return result
  }
  let id : Int = match result.value {
    Object(fields) => @json.from_json(fields["id"])
    _ => raise InvalidInput("Missing comment")
  }
  let row = wp_comment_row(input, content, id).unwrap()
  {
    ..result,
    value: rest_wp_comment_value(
      row,
      rest_all_posts_at(input, content),
      base,
      false,
      edit=true,
    ),
  }
}

///|
fn rest_wp_comment_update(
  input : String,
  content : AuthoringDirectory,
  principal : AccessPrincipal,
  path : String,
  query : Map[String, String],
  expected : String?,
  body : Bytes,
  base : String,
  verb : String,
) -> RestResponse raise {
  if !role_capabilities(principal.role).contains("moderate_comments") {
    return rest_error(403, "rest_cannot_edit")
  }
  for key, value in query {
    if key != "context" || !["view", "embed", "edit"].contains(value) {
      return rest_error(400, "rest_invalid_param")
    }
  }
  let id = rest_wp_comment_id(path).unwrap()
  let row = match wp_comment_row(input, content, id) {
    Some(row) => row
    None => return rest_error(404, "rest_comment_invalid_id")
  }
  if row.comment.status == "trash" {
    return rest_error(409, "moonpress_comment_trashed")
  }
  let fields = strict_json_object(
    @json.parse(decode_text(body, "Comment update")),
    ["status", "content"],
    "Comment update",
  ) catch {
    _ => return rest_error(400, "rest_invalid_param")
  }
  if fields.contains("content") {
    fields["content"] = wp_comment_input(fields["content"]).to_json() catch {
      _ => return rest_error(400, "rest_invalid_param")
    }
    if fields.get("status") is Some(String("approve")) {
      fields["status"] = "approved".to_json()
    }
    return wp_comment_result(
      input,
      content,
      native_comment_edit(input, content, id, expected, fields),
      base,
    )
  }
  let status = match fields.get("status") {
    Some(String("approve")) => "approved"
    Some(String("hold")) => "hold"
    Some(String("spam")) => "spam"
    _ => return rest_error(400, "rest_invalid_param")
  }
  let result = native_comment_change(input, content, id, expected, status)
  wp_comment_result(input, content, result, base)
}
