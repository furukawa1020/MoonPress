///|
fn rest_wp_comment_id(path : String) -> Int? {
  let prefix = "/wp-json/wp/v2/comments"
  if path == prefix || path == prefix + "/" {
    return Some(0)
  }
  if !path.has_prefix(prefix + "/") {
    return None
  }
  let tail = path[prefix.length() + 1:].to_owned()
  let tail = if tail.has_suffix("/") {
    tail[:tail.length() - 1].to_owned()
  } else {
    tail
  }
  Some(rest_positive(tail, 2147483647)) catch {
    _ => None
  }
}

///|
fn rest_wp_comment_value(
  row : CommentRow,
  articles : Array[RestPost],
  base : String,
  embed : Bool,
) -> Json raise {
  let c = row.comment
  let native = native_comment_value(row, false)
  let content = match native {
    Object(fields) => fields["content"]
    _ => Json::null()
  }
  let mut link = ""
  for post in articles {
    if post.document.wp_id == Some(c.post) {
      link = base +
        url_component(post.document.slug.unwrap_or(post.stem) + ".html") +
        "#comment-" +
        c.id.to_string()
    }
  }
  let date = rest_now_utc(instant=c.created)
  let fields : Map[String, Json] = Map([
    ("id", c.id.to_json()),
    ("author", c.author.to_json()),
    ("author_name", c.author_name.to_json()),
    ("author_url", "".to_json()),
    ("content", content),
    ("date", date.to_json()),
    ("link", link.to_json()),
    ("parent", c.parent.unwrap_or(0).to_json()),
    ("type", "comment".to_json()),
  ])
  if !embed {
    fields["date_gmt"] = date.to_json()
    fields["post"] = c.post.to_json()
    fields["status"] = "approved".to_json()
  }
  Json::object(fields)
}

///|
fn rest_wp_comments(
  input : String,
  path : String,
  query : Map[String, String],
  base : String,
) -> RestResponse raise {
  let id = rest_wp_comment_id(path).unwrap()
  let embed = query.get("context") == Some("embed")
  if query.get("context") is Some(value) && !["view", "embed"].contains(value) {
    return rest_error(400, "rest_invalid_param")
  }
  if query.get("status") is Some(value) && value != "approve" {
    return rest_error(400, "rest_invalid_param")
  }
  if query.get("type") is Some(value) && value != "comment" {
    return rest_error(400, "rest_invalid_param")
  }
  if id > 0 && query.keys().any(key => key != "context") {
    return rest_error(400, "rest_invalid_param")
  }
  let selected = query.copy()
  selected["context"] = "view"
  selected.remove("type")
  if id == 0 {
    selected["status"] = "approved"
    selected["orderby"] = match query.get("orderby").unwrap_or("date_gmt") {
      "date_gmt" | "date" => "date"
      "id" => "id"
      _ => return rest_error(400, "rest_invalid_param")
    }
    selected["order"] = query.get("order").unwrap_or("desc")
  }
  if id == 0 {
    let (page, size, offset) = (
      rest_positive(query.get("page").unwrap_or("1"), 4096),
      rest_positive(query.get("per_page").unwrap_or("10"), 100),
      rest_nonnegative(query.get("offset").unwrap_or("0"), 409600),
    ) catch {
      _ => return rest_error(400, "rest_invalid_param")
    }
    selected["offset"] = (if offset == 0 { (page - 1) * size } else { offset }).to_string()
    selected["page"] = "1"
  }
  let content = open_authoring_subdirectory(input, "content")
  defer directory_close(content.fd)
  content.lock()
  let articles = rest_all_posts_at(input, content)
  let result = native_comments_read(
    input,
    content,
    None,
    id,
    selected,
    projection=Some(row => rest_wp_comment_value(row, articles, base, embed)),
  )
  if result.code == 404 {
    rest_error(404, "rest_comment_invalid_id")
  } else {
    result
  }
}
