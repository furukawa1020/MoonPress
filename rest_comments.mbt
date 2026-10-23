///|
fn native_comment_id(path : String) -> Int? {
  let parts = native_parts(path)
  if parts.length() == 1 && parts[0] == "comments" {
    return Some(0)
  }
  if parts.length() == 2 && parts[0] == "comments" {
    return Some(rest_positive(parts[1], 2147483647)) catch { _ => None }
  }
  None
}

///|
fn native_comment_value(row : CommentRow, edit : Bool) -> Json {
  let comment = row.comment
  let body : Map[String, Json] = Map([
    (
      "rendered",
      ("<p>" +
      escape_html(comment.content).replace_all(old="\n", new="<br>\n") +
      "</p>\n").to_json(),
    ),
  ])
  let fields : Map[String, Json] = Map([
    ("id", comment.id.to_json()),
    ("post", comment.post.to_json()),
    ("author_name", comment.author_name.to_json()),
    ("created", comment.created.to_json()),
    ("status", comment.status.to_json()),
    ("content", Json::object(body)),
  ])
  if edit {
    body["raw"] = comment.content.to_json()
    fields["author"] = comment.author.to_json()
  }
  Json::object(fields)
}

///|
fn native_comment_create(
  input : String,
  content : AuthoringDirectory,
  principal : AccessPrincipal,
  query : Map[String, String],
  body : Bytes,
) -> RestResponse raise {
  if !query.is_empty() {
    return rest_error(400, "rest_invalid_param")
  }
  let (post, text, label) = try {
    let fields = strict_json_object(
      @json.parse(decode_text(body, "Comment body")),
      ["post", "content", "author_name"],
      "Comment body",
    )
    let post = rest_positive(
      fields.get("post").unwrap_or(Json::null()).stringify(),
      2147483647,
    )
    let text = match fields.get("content") {
      Some(String(text)) =>
        text.replace_all(old="\r\n", new="\n").replace_all(old="\r", new="\n")
      _ => raise InvalidInput("Expected comment text")
    }
    let label = match fields.get("author_name") {
      Some(String(label)) => label.trim().to_owned()
      _ => raise InvalidInput("Expected public author label")
    }
    comment_text(text, 8192)
    comment_text(label, 80)
    if label.any(c => c.is_control()) {
      raise InvalidInput("Invalid public name")
    }
    (post, text, label)
  } catch {
    _ => return rest_error(400, "rest_invalid_param")
  }
  let now = authoring_time()
  let public = rest_all_posts_at(input, content).any(row => {
    row.document.wp_id == Some(post) &&
    !row.document.draft &&
    row.document.listed &&
    publication_due(row.document.publish_at, now)
  })
  if !public {
    return rest_error(404, "rest_post_invalid_id")
  }
  let log = comment_open(input, content, create=true).unwrap()
  defer directory_close(log.fd)
  log.lock()
  let state = comment_replay(log)
  if state.rows.length() >= 1024 {
    return rest_error(409, "moonpress_comment_limit")
  }
  if now < 0 {
    raise InvalidInput("Invalid clock")
  }
  let comment : NativeComment = {
    id: state.rows.length() + 1,
    post,
    author: principal.id,
    author_name: label,
    content: text,
    status: "hold",
    created: now,
  }
  let row = comment_append(log, state, comment, "create")
  {
    ..rest_ok(
      native_comment_value(row, true),
      etag=Some(row.revision),
      location=Some("/wp-json/moonpress/v1/comments/" + comment.id.to_string()),
    ),
    code: 201,
  }
}
