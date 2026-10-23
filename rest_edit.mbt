///|
fn rest_edit_target(path : String) -> (String, Int)? raise {
  let (kind, tail) = if path.has_prefix("/wp-json/wp/v2/posts/") {
    ("post", path[21:].to_owned())
  } else if path.has_prefix("/wp-json/wp/v2/pages/") {
    ("page", path[21:].to_owned())
  } else {
    return None
  }
  Some((kind, rest_positive(tail, 2147483647)))
}

///|
fn rest_edit_value(
  document : Document,
  stem : String,
  base : String,
  digest : String,
) -> Json raise {
  let value = rest_post_value(document, stem, base)
  let fields = match value {
    Object(fields) => fields
    _ => raise InvalidInput("Expected post object")
  }
  fields["status"] = (if document.draft {
    "draft"
  } else if !publication_due(document.publish_at, authoring_time()) {
    "future"
  } else {
    "publish"
  }).to_json()
  fields["title"] = {
    "raw": document.title.to_json(),
    "rendered": escape_html(document.title).to_json(),
  }
  let content = render_markdown(document.body)
  fields["content"] = {
    "raw": content.to_json(),
    "rendered": content.to_json(),
    "protected": false.to_json(),
  }
  fields["excerpt"] = {
    "raw": document.description.to_json(),
    "rendered": ("<p>" + escape_html(document.description) + "</p>\n").to_json(),
    "protected": false.to_json(),
  }
  fields["moonpress_revision"] = digest.to_json()
  value
}

///|
fn rest_find_post(
  input : String,
  directory : AuthoringDirectory,
  kind : String,
  id : Int,
) -> (String, PostSnapshot, Document)? raise {
  let names = post_names(input)
  if names.length() > 4096 {
    raise InvalidInput("REST source count exceeds limit")
  }
  let ids : Map[Int, Bool] = Map([])
  let mut found = None
  let mut total = 0
  for name in names {
    if !name.has_suffix(".md") {
      continue
    }
    require_post_name(name)
    let bytes = directory.read(name, max_bytes=4194304)
    total += bytes.length()
    if total > 16777216 {
      raise InvalidInput("REST source total exceeds limit")
    }
    let content = decode_text(bytes, name)
    let document = parse_document(
      content,
      name[:name.length() - 3].to_owned(),
      filename=name,
    )
    if document.wp_id is Some(current) {
      if ids.contains(current) {
        raise InvalidInput("Duplicate REST identity")
      }
      ids[current] = true
      if current == id && document.kind == kind {
        found = Some(
          (
            name,
            {
              source: "content/" + name,
              content,
              digest: digest_text(content),
            },
            document,
          ),
        )
      }
    }
  }
  found
}

///|
fn rest_update_source(
  source : String,
  document : Document,
  body : Bytes,
  principal : AccessPrincipal,
) -> String raise {
  let changes = strict_json_object(
    @json.parse(decode_text(body, "REST body")),
    ["title", "content", "excerpt", "status", "date_gmt"],
    "REST update",
  )
  for _, value in changes {
    if !(value is String(_)) {
      raise InvalidInput("REST update values must be strings")
    }
  }
  let (metadata, current_body) = document_parts(source, "REST post")
  let fields = match metadata {
    Object(fields) => fields
    _ => raise InvalidInput("Expected metadata")
  }
  let before = metadata.stringify()
  let mut next_body = current_body
  for key in ["title", "excerpt", "content"] {
    if changes.get(key) is Some(String(value)) {
      if key == "title" {
        if value.trim().is_empty() {
          raise InvalidInput("Empty native title")
        }
        if value != document.title {
          fields["title"] = value.to_json()
        }
      } else if key == "excerpt" {
        if wxr_has_markup(value) {
          raise InvalidInput("Excerpt HTML is unsupported")
        }
        if value != document.description {
          fields["description"] = value.to_json()
        }
      } else if value != render_markdown(document.body) {
        next_body = wxr_body(value)
      }
    }
  }
  let mut timestamp = document.publish_at
  if changes.get("date_gmt") is Some(String(value)) {
    if value.length() != 19 {
      raise InvalidInput("date_gmt requires UTC YYYY-MM-DDTHH:MM:SS")
    }
    publication_timestamp(value + "Z") |> ignore
    timestamp = Some(value + "Z")
    fields["publish_at"] = (value + "Z").to_json()
    fields["date"] = value[:10].to_owned().to_json()
  }
  if changes.get("status") is Some(String(status)) {
    if !["draft", "publish", "future"].contains(status) {
      raise InvalidInput("Unsupported native status")
    }
    if status != "draft" &&
      !role_capabilities(principal.role).contains(
        "publish_" + (if document.kind == "page" { "pages" } else { "posts" }),
      ) {
      raise InvalidInput("Publish capability required")
    }
    if status == "future" &&
      (timestamp is None || publication_due(timestamp, authoring_time())) {
      raise InvalidInput("Future status needs a future date_gmt")
    }
    if status == "publish" &&
      !changes.contains("date_gmt") &&
      !publication_due(timestamp, authoring_time()) {
      fields.remove("publish_at")
    }
    if document.draft != (status == "draft") {
      fields["draft"] = (status == "draft").to_json()
    }
  }
  // A contributor cannot schedule/publish indirectly through a date-only edit.
  if !document.draft &&
    changes.contains("date_gmt") &&
    !role_capabilities(principal.role).contains(
      "publish_" + (if document.kind == "page" { "pages" } else { "posts" }),
    ) {
    raise InvalidInput("Publication date change requires publish capability")
  }
  if before == metadata.stringify() && next_body == current_body {
    return source
  }
  let next = "---\n" + metadata.stringify() + "\n---\n" + next_body
  if @utf8.encode(next).length() > 4194304 {
    raise InvalidInput("REST source exceeds editor limit")
  }
  parse_document(next, document.title) |> ignore
  next
}

///|
fn rest_edit(
  input : String,
  path : String,
  query : Map[String, String],
  base : String,
  authorization : String?,
  body : Bytes?,
  if_match : String?,
) -> RestResponse raise {
  let target = rest_edit_target(path) catch {
    _ => return rest_error(400, "rest_invalid_param")
  }
  let (kind, id) = match target {
    Some(target) => target
    None =>
      return rest_error(if body is None { 400 } else { 405 }, "rest_no_route")
  }
  for key, value in query {
    if key != "context" || value != "edit" {
      return rest_error(400, "rest_invalid_param")
    }
  }
  rest_with_access(input, authorization, fn(principal, directory) raise {
    let (name, snapshot, document) = match
      rest_find_post(input, directory, kind, id) {
      Some(found) => found
      None => return rest_error(404, "rest_post_invalid_id")
    }
    if !role_can_edit(
        principal.role,
        principal.id,
        document.author,
        document.kind,
        !document.draft,
      ) {
      return rest_error(403, "rest_cannot_edit")
    }
    let stem = name[:name.length() - 3].to_owned()
    if body is None {
      return rest_ok(
        rest_edit_value(document, stem, base, snapshot.digest),
        etag=Some(snapshot.digest),
      )
    }
    let expected = match if_match {
      Some(value) => value
      None => return rest_error(428, "moonpress_precondition_required")
    }
    if expected.length() != 66 ||
      !expected.has_prefix("\"") ||
      !expected.has_suffix("\"") ||
      !valid_digest(expected[1:65].to_owned()) {
      return rest_error(400, "moonpress_invalid_precondition")
    }
    if expected[1:65].to_owned() != snapshot.digest {
      return rest_error(412, "moonpress_source_changed")
    }
    let request_json = @json.parse(decode_text(body.unwrap(), "REST body")) catch {
      _ => return rest_error(400, "rest_invalid_param")
    }
    if request_json is Object(fields) {
      if fields.get("status") is Some(String(status)) &&
        ["publish", "future"].contains(status) &&
        !role_capabilities(principal.role).contains(
          "publish_" + (if kind == "page" { "pages" } else { "posts" }),
        ) {
        return rest_error(403, "rest_cannot_publish")
      }
    }
    let next = rest_update_source(
      snapshot.content,
      document,
      body.unwrap(),
      principal,
    ) catch {
      _ => return rest_error(400, "rest_invalid_param")
    }
    let report = save_post_at(input, directory, name, snapshot.digest, next)
    rest_ok(
      rest_edit_value(parse_document(next, stem), stem, base, report.digest),
      etag=Some(report.digest),
    )
  })
}
