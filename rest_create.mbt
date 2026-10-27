///|
fn rest_title_slug(title : String) -> String {
  let out = StringBuilder()
  let mut length = 0
  let mut dash = false
  for c in title.to_lower() {
    if c.is_whitespace() || c == '-' {
      dash = length > 0
      continue
    }
    if c.is_ascii_alphabetic() ||
      c.is_ascii_digit() ||
      (c.to_int() > 127 && !c.is_control()) {
      let size = @utf8.encode(c.to_string()).length()
      if length + size + (if dash { 1 } else { 0 }) > 200 {
        break
      }
      if dash {
        out.write_string("-")
        length += 1
        dash = false
      }
      out.write_char(c)
      length += size
    }
  }
  out.to_string()
}

///|
fn rest_create(
  input : String,
  path : String,
  query : Map[String, String],
  base : String,
  authorization : String?,
  body : Bytes,
) -> RestResponse raise {
  for key, value in query {
    if key != "context" || value != "edit" {
      return rest_error(400, "rest_invalid_param")
    }
  }
  rest_with_access_users(input, authorization, fn(
    principal,
    directory,
    users,
  ) raise {
    let kind = if path.has_prefix("/wp-json/wp/v2/posts") {
      "post"
    } else {
      "page"
    }
    let capabilities = role_capabilities(principal.role)
    let suffix = if kind == "page" { "pages" } else { "posts" }
    if !capabilities.contains("edit_" + suffix) {
      return rest_error(403, "rest_cannot_create")
    }
    let fields = try {
      let fields = strict_json_object(
        @json.parse(decode_text(body, "REST creation")),
        [
          "title", "content", "excerpt", "slug", "status", "date_gmt", "moonpress_categories",
          "moonpress_tags", "author", "date",
        ],
        "REST creation",
      )
      rest_input_date(fields)
      rest_write_types(fields)
      fields
    } catch {
      _ => return rest_error(400, "rest_invalid_param")
    }
    let text = fn(key : String, fallback : String) {
      match fields.get(key) {
        Some(String(value)) => value
        _ => fallback
      }
    }
    let (author_code, author) = rest_assign_author(
      users,
      principal,
      kind,
      fields.get("author"),
    )
    if author_code != 200 {
      return rest_error(
        author_code,
        if author_code == 403 {
          "rest_cannot_edit_others"
        } else {
          "rest_invalid_author"
        },
      )
    }
    let title = text("title", "")
    let status = text("status", "draft")
    if title.trim().is_empty() ||
      !["draft", "publish", "future"].contains(status) {
      return rest_error(400, "rest_invalid_param")
    }
    if status != "draft" && !capabilities.contains("publish_" + suffix) {
      return rest_error(403, "rest_cannot_publish")
    }
    let requested = text("slug", rest_title_slug(title))
    if (!requested.is_empty() && !valid_slug(requested)) ||
      @utf8.encode(requested).length() > 230 {
      return rest_error(400, "rest_invalid_param")
    }
    let metadata : Json = {
      "kind": kind,
      "title": title,
      "draft": status == "draft",
      "author": author,
      "description": text("excerpt", ""),
    }
    let attributes = match metadata {
      Object(fields) => fields
      _ => raise InvalidInput("Expected metadata")
    }
    for
      (key, field) in [
        ("moonpress_categories", "categories"),
        ("moonpress_tags", "tags"),
      ] {
      if fields.get(key) is Some(value) {
        attributes[field] = rest_named_terms(value).to_json()
      }
    }
    if wxr_has_markup(text("excerpt", "")) {
      return rest_error(400, "rest_invalid_param")
    }
    let content = wxr_body(text("content", "")) catch {
      _ => return rest_error(400, "rest_invalid_param")
    }
    let now = rest_now_utc()
    attributes["publish_at"] = (now + "Z").to_json()
    attributes["date"] = now[:10].to_owned().to_json()
    if fields.contains("date_gmt") {
      let date = text("date_gmt", "")
      if date.length() != 19 {
        return rest_error(400, "rest_invalid_param")
      }
      let _ = publication_timestamp(date + "Z") catch {
        _ => return rest_error(400, "rest_invalid_param")
      }
      attributes["publish_at"] = (date + "Z").to_json()
      attributes["date"] = date[:10].to_owned().to_json()
    }
    let candidate = "---\n" + metadata.stringify() + "\n---\n" + content
    let document = parse_document(candidate, title)
    if status == "future" &&
      (
        document.publish_at is None ||
        publication_due(document.publish_at, authoring_time())
      ) {
      return rest_error(400, "rest_invalid_param")
    }
    let existing = rest_all_posts_at(input, directory, unassigned=true)
    let mut maximum = 0
    for post in existing {
      maximum = if maximum > post.document.wp_id.unwrap_or(0) {
        maximum
      } else {
        post.document.wp_id.unwrap_or(0)
      }
    }
    let id = rest_reserve_id(input, directory, maximum)
    let requested = if requested.is_empty() {
      kind + "-" + id.to_string()
    } else {
      requested
    }
    let mut slug = requested
    let mut attempt = 1
    while directory.kind(slug + ".md") != 0 ||
          existing.any(post => post.document.slug.unwrap_or(post.stem) == slug) {
      attempt += 1
      if attempt > 128 {
        return rest_error(409, "rest_slug_conflict")
      }
      slug = requested + "-" + attempt.to_string()
    }
    attributes["wp_id"] = id.to_json()
    let source = "---\n" + metadata.stringify() + "\n---\n" + content
    if @utf8.encode(source).length() > 4194304 {
      return rest_error(400, "rest_invalid_param")
    }
    directory.write_new(slug + ".md", @utf8.encode(source), private_mode=true)
    let digest = digest_text(source)
    let result = rest_ok(
      rest_edit_value(parse_document(source, slug), slug, base, digest),
      etag=Some(digest),
      location=Some(
        "/wp-json/wp/v2/" +
        (if kind == "page" { "pages" } else { "posts" }) +
        "/" +
        id.to_string(),
      ),
    )
    { ..result, code: 201, }
  })
}
