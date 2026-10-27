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
  let row = match comment_append(log, state, comment, "create") {
    Some(row) => row
    None => return rest_error(409, "moonpress_comment_storage_full")
  }
  {
    ..rest_ok(native_comment_value(row, true), etag=Some(row.revision)),
    code: 201,
  }
}

///|
fn native_comments_read(
  input : String,
  content : AuthoringDirectory,
  principal : AccessPrincipal?,
  id : Int,
  query : Map[String, String],
) -> RestResponse raise {
  let embed = query.get("context") == Some("embed")
  let edit = query.get("context") == Some("edit")
  if edit && principal is None {
    return rest_error(401, "rest_not_logged_in")
  }
  let status = query
    .get("status")
    .unwrap_or(if edit { "any" } else { "approved" })
  for key, value in query {
    if ![
        "context", "status", "post", "page", "per_page", "search", "orderby", "order",
        "include", "exclude", "author", "author_exclude", "after", "before",
      ].contains(key) ||
      (id > 0 && key != "context") ||
      (
        key == "context" &&
        value != "view" &&
        value != "edit" &&
        value != "embed"
      ) {
      return rest_error(400, "rest_invalid_param")
    }
  }
  if !["any", "approved", "hold", "spam", "trash"].contains(status) ||
    (!edit && status != "approved") {
    return rest_error(400, "rest_invalid_param")
  }
  let orderby = query.get("orderby").unwrap_or("id")
  let order = query.get("order").unwrap_or("asc")
  if !["id", "date"].contains(orderby) || !["asc", "desc"].contains(order) {
    return rest_error(400, "rest_invalid_param")
  }
  let (included, excluded) = (
    rest_id_list(query.get("include")),
    rest_id_list(query.get("exclude")),
  ) catch {
    _ => return rest_error(400, "rest_invalid_param")
  }
  let (after, before) = (
    query.get("after").map(value => rest_date_bound(value)),
    query.get("before").map(value => rest_date_bound(value)),
  ) catch {
    _ => return rest_error(400, "rest_invalid_param")
  }
  let (authors, excluded_authors) = (
    rest_author_ids(query.get("author")),
    rest_author_ids(query.get("author_exclude")),
  ) catch {
    _ => return rest_error(400, "rest_invalid_param")
  }
  let search = native_query_text(query.get("search").unwrap_or("")) catch {
    _ => return rest_error(400, "rest_invalid_param")
  }
  let posts = try {
    rest_page_bounds(0, query) |> ignore
    rest_id_list(query.get("post"))
  } catch {
    _ => return rest_error(400, "rest_invalid_param")
  }
  let public : Map[Int, Bool] = Map([])
  if !edit {
    let now = authoring_time()
    for article in rest_all_posts_at(input, content) {
      let doc = article.document
      if !doc.draft && doc.listed && publication_due(doc.publish_at, now) {
        public[doc.wp_id.unwrap()] = true
      }
    }
  }
  let rows = match comment_open(input, content) {
    Some(log) => {
      defer directory_close(log.fd)
      log.lock()
      comment_replay(log).rows
    }
    None => []
  }
  let moderator = match principal {
    Some(user) => role_capabilities(user.role).contains("moderate_comments")
    None => false
  }
  let allowed = rows.filter(row => {
    let item = row.comment
    (item.content + "\n" + item.author_name).to_lower().contains(search) &&
    (included.is_empty() || included.contains(item.id)) &&
    !excluded.contains(item.id) &&
    (after is None || item.created > after.unwrap()) &&
    (before is None || item.created < before.unwrap()) &&
    (authors.is_empty() || authors.contains(item.author)) &&
    !excluded_authors.contains(item.author) &&
    (posts.is_empty() || posts.contains(item.post)) &&
    (status == "any" || item.status == status) &&
    (if edit {
      moderator || principal.unwrap().id == item.author
    } else {
      item.status == "approved" && public.contains(item.post)
    })
  })
  allowed.sort_by(fn(a, b) {
    let compared = if orderby == "date" {
      a.comment.created.compare(b.comment.created)
    } else {
      a.comment.id.compare(b.comment.id)
    }
    let compared = if compared == 0 {
      a.comment.id.compare(b.comment.id)
    } else {
      compared
    }
    if order == "asc" {
      compared
    } else {
      0 - compared
    }
  })
  if id > 0 {
    for row in allowed {
      if row.comment.id == id {
        return rest_ok(
          native_comment_project(row, edit, embed),
          etag=if edit { Some(row.revision) } else { None },
        )
      }
    }
    return rest_error(404, "moonpress_comment_missing")
  }
  let (start, size, pages) = match rest_page_bounds(allowed.length(), query) {
    Some(bounds) => bounds
    None => return rest_error(400, "rest_post_invalid_page_number")
  }
  let selected : Array[Json] = []
  for i = start; i < allowed.length() && i < start + size; i = i + 1 {
    selected.push(native_comment_project(allowed[i], edit, embed))
  }
  {
    ..rest_ok(selected.to_json()),
    total: Some(allowed.length()),
    pages: Some(pages),
  }
}

///|
fn native_comment_moderate(
  input : String,
  content : AuthoringDirectory,
  principal : AccessPrincipal,
  id : Int,
  query : Map[String, String],
  expected : String?,
  body : Bytes,
  verb : String,
) -> RestResponse raise {
  if !role_capabilities(principal.role).contains("moderate_comments") {
    return rest_error(403, "moonpress_cannot_moderate")
  }
  for key, value in query {
    if key != "context" || value != "edit" {
      return rest_error(400, "rest_invalid_param")
    }
  }
  let status = if verb == "DELETE" {
    "trash"
  } else {
    try {
      let fields = strict_json_object(
        @json.parse(decode_text(body, "Moderation")),
        ["status"],
        "Moderation",
      )
      match fields.get("status") {
        Some(String(status)) if ["approved", "hold", "spam"].contains(status) =>
          status
        _ => raise InvalidInput("Unsupported comment status")
      }
    } catch {
      _ => return rest_error(400, "rest_invalid_param")
    }
  }
  native_comment_change(input, content, id, expected, status)
}

///|
fn native_comment_change(
  input : String,
  content : AuthoringDirectory,
  id : Int,
  expected : String?,
  status : String,
) -> RestResponse raise {
  if !["approved", "hold", "spam", "trash"].contains(status) {
    return rest_error(400, "rest_invalid_param")
  }
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
  if current.comment.status == "trash" && status != "hold" && status != "trash" {
    return rest_error(409, "moonpress_comment_trashed")
  }
  if current.comment.status == status {
    return rest_ok(
      native_comment_value(current, true),
      etag=Some(current.revision),
    )
  }
  let next = { ..current.comment, status, }
  let row = match comment_append(log, state, next, "status") {
    Some(row) => row
    None => return rest_error(409, "moonpress_comment_storage_full")
  }
  rest_ok(native_comment_value(row, true), etag=Some(row.revision))
}
