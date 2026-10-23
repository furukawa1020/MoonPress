///|
fn native_taxonomy(path : String) -> String? {
  let parts = native_parts(path)
  if parts == ["categories"] {
    Some("categories")
  } else if parts == ["tags"] {
    Some("tags")
  } else {
    None
  }
}

///|
fn native_taxonomy_read(
  input : String,
  content : AuthoringDirectory,
  kind : String,
  query : Map[String, String],
) -> RestResponse raise {
  for key, _ in query {
    if !["page", "per_page"].contains(key) {
      return rest_error(400, "rest_invalid_param")
    }
  }
  try rest_page_bounds(0, query) |> ignore catch {
    _ => return rest_error(400, "rest_invalid_param")
  }
  let counts : Map[String, Int] = Map([])
  let now = authoring_time()
  for post in rest_all_posts_at(input, content) {
    let doc = post.document
    if doc.kind != "post" ||
      doc.draft ||
      !doc.listed ||
      !publication_due(doc.publish_at, now) {
      continue
    }
    let names = if kind == "categories" { doc.categories } else { doc.tags }
    for name in names {
      counts[name] = counts.get(name).unwrap_or(0) + 1
      if counts.length() > 4096 {
        raise InvalidInput("Taxonomy name limit")
      }
    }
  }
  let names = counts.keys().to_array()
  names.sort()
  let (start, size, pages) = match rest_page_bounds(names.length(), query) {
    Some(value) => value
    None => return rest_error(400, "rest_post_invalid_page_number")
  }
  let rows : Array[Json] = []
  for i = start; i < names.length() && i < start + size; i = i + 1 {
    rows.push({
      "name": names[i].to_json(),
      "count": counts[names[i]].to_json(),
      "taxonomy": kind.to_json(),
    })
  }
  {
    ..rest_ok(rows.to_json()),
    total: Some(names.length()),
    pages: Some(pages),
  }
}
