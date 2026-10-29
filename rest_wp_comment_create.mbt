///|
fn rest_wp_comment_create(
  input : String,
  content : AuthoringDirectory,
  principal : AccessPrincipal,
  query : Map[String, String],
  body : Bytes,
  base : String,
) -> RestResponse raise {
  let selected = query.copy()
  if selected.get("context") is Some(value) &&
    !["view", "embed", "edit"].contains(value) {
    return rest_error(400, "rest_invalid_param")
  }
  selected.remove("context")
  let result = native_comment_create(input, content, principal, selected, body)
  if result.code != 201 {
    return result
  }
  let id : Int = match result.value {
    Object(fields) => @json.from_json(fields["id"])
    _ => raise InvalidInput("Missing created comment")
  }
  let log = comment_open(input, content).unwrap()
  defer directory_close(log.fd)
  log.lock()
  let state = comment_replay(log)
  let row = state.rows[id - 1]
  {
    ..result,
    value: rest_wp_comment_value(
      row,
      rest_all_posts_at(input, content),
      base,
      false,
      edit=true,
    ),
    location: Some("/wp-json/wp/v2/comments/" + id.to_string()),
  }
}
