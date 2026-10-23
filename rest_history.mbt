///|
fn native_history_record(
  input : String,
  content : AuthoringDirectory,
  record : String,
) -> RevisionSnapshot? raise {
  let vault = open_authoring_subdirectory(input, ".moonpress-history")
  defer directory_close(vault.fd)
  require_same_authoring_site(content, vault)
  vault.lock()
  if vault.kind(record) == 0 {
    return None
  }
  Some(read_authoring_record(vault, record))
}

///|
fn native_revision_value(record : RevisionSummary) -> Json {
  {
    "id": record.id.to_json(),
    "digest": record.digest.to_json(),
    "created": record.created.to_json(),
    "bytes": record.bytes.to_json(),
  }
}

///|
fn native_history_read(
  input : String,
  content : AuthoringDirectory,
  principal : AccessPrincipal,
  kind : String,
  id : Int,
  record : String?,
  query : Map[String, String],
  base : String,
) -> RestResponse raise {
  for key, value in query {
    if !["context", "page", "per_page"].contains(key) ||
      (key == "context" && value != "edit") ||
      (record is Some(_) && key != "context") {
      return rest_error(400, "rest_invalid_param")
    }
  }
  try {
    rest_positive(query.get("page").unwrap_or("1"), 4096) |> ignore
    rest_positive(query.get("per_page").unwrap_or("10"), 100) |> ignore
  } catch {
    _ => return rest_error(400, "rest_invalid_param")
  }
  let (name, _, document) = match rest_find_post(input, content, kind, id) {
    Some(found) => found
    None => return rest_error(404, "rest_post_invalid_id")
  }
  if !role_can_edit(
      principal.role,
      principal.id,
      document.author,
      kind,
      !document.draft,
    ) {
    return rest_error(403, "rest_cannot_edit")
  }
  if record is Some(record) {
    if path_kind(input + "/.moonpress-history") == 0 {
      return rest_error(404, "moonpress_revision_missing")
    }
    if !record.has_prefix(digest_text(name) + "-") {
      return rest_error(404, "moonpress_revision_missing")
    }
    let saved = match native_history_record(input, content, record) {
      Some(saved) => saved
      None => return rest_error(404, "moonpress_revision_missing")
    }
    if saved.revision.name != name {
      return rest_error(404, "moonpress_revision_missing")
    }
    let stem = name[:name.length() - 3].to_owned()
    let historical = parse_document(saved.content, stem)
    if historical.wp_id != Some(id) ||
      historical.author != document.author ||
      historical.kind != kind {
      return rest_error(404, "moonpress_revision_missing")
    }
    let historical = {
      ..historical,
      wp_id: Some(id),
      author: document.author,
      kind,
    }
    return rest_ok(
      {
        "revision": native_revision_value(saved.revision),
        "article": rest_edit_value(
          historical,
          stem,
          base,
          saved.revision.digest,
        ),
      },
      etag=Some(saved.revision.record_digest),
    )
  }
  let rows : Array[Json] = []
  if path_kind(input + "/.moonpress-history") != 0 {
    let vault = open_authoring_subdirectory(input, ".moonpress-history")
    defer directory_close(vault.fd)
    require_same_authoring_site(content, vault)
    vault.lock()
    let names = vault.names()
    if names.length() > 4096 {
      raise InvalidInput("History entry limit")
    }
    names.sort()
    let mut bytes = 0
    for entry in names {
      require_record_id(entry)
      if !entry.has_prefix(digest_text(name) + "-") {
        continue
      }
      let saved = read_authoring_record(vault, entry)
      bytes += saved.revision.bytes
      if bytes > 16777216 {
        raise InvalidInput("History snapshot byte limit")
      }
      if saved.revision.name != name {
        raise InvalidInput("History identity mismatch")
      }
      let historical = parse_document(saved.content, name)
      if historical.wp_id == Some(id) &&
        historical.author == document.author &&
        historical.kind == kind {
        rows.push(native_revision_value(saved.revision))
      }
    }
  }
  let (start, size, pages) = match rest_page_bounds(rows.length(), query) {
    Some(bounds) => bounds
    None => return rest_error(400, "rest_post_invalid_page_number")
  }
  let selected : Array[Json] = []
  for i = start; i < rows.length() && i < start + size; i = i + 1 {
    selected.push(rows[i])
  }
  {
    ..rest_ok(selected.to_json()),
    total: Some(rows.length()),
    pages: Some(pages),
  }
}

///|
fn native_history_restore(
  input : String,
  content : AuthoringDirectory,
  principal : AccessPrincipal,
  kind : String,
  id : Int,
  record : String,
  query : Map[String, String],
  base : String,
  expected : String?,
  body : Bytes,
) -> RestResponse raise {
  if !query.is_empty() {
    return rest_error(400, "rest_invalid_param")
  }
  try
    strict_json_object(
      @json.parse(decode_text(body, "Restore body")),
      [],
      "Restore body",
    )
    |> ignore
  catch {
    _ => return rest_error(400, "rest_invalid_param")
  }
  let (name, snapshot, document) = match
    rest_find_post(input, content, kind, id) {
    Some(found) => found
    None => return rest_error(404, "rest_post_invalid_id")
  }
  if !role_can_edit(
      principal.role,
      principal.id,
      document.author,
      kind,
      !document.draft,
    ) {
    return rest_error(403, "rest_cannot_edit")
  }
  if rest_precondition(expected, snapshot.digest) is Some(error) {
    return error
  }
  if !record.has_prefix(digest_text(name) + "-") ||
    path_kind(input + "/.moonpress-history") == 0 {
    return rest_error(404, "moonpress_revision_missing")
  }
  let saved = match native_history_record(input, content, record) {
    Some(saved) => saved
    None => return rest_error(404, "moonpress_revision_missing")
  }
  let stem = name[:name.length() - 3].to_owned()
  let historical = parse_document(saved.content, stem)
  if saved.revision.name != name ||
    historical.wp_id != Some(id) ||
    historical.author != document.author ||
    historical.kind != kind {
    return rest_error(404, "moonpress_revision_missing")
  }
  if !historical.draft &&
    !role_capabilities(principal.role).contains(
      "publish_" + (if kind == "page" { "pages" } else { "posts" }),
    ) {
    return rest_error(403, "rest_cannot_publish")
  }
  let slug = historical.slug.unwrap_or(stem)
  for post in rest_all_posts_at(input, content, unassigned=true) {
    if post.stem != stem &&
      (post.stem == slug || post.document.slug.unwrap_or(post.stem) == slug) {
      return rest_error(409, "rest_slug_conflict")
    }
  }
  let report = save_post_at(
    input,
    content,
    name,
    snapshot.digest,
    saved.content,
  )
  rest_ok(
    rest_edit_value(historical, stem, base, report.digest),
    etag=Some(report.digest),
  )
}
