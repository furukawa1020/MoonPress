///|
fn rest_term_search(
  input : String,
  query : Map[String, String],
  base : String,
) -> RestResponse raise {
  for key, _ in query {
    if ![
        "context", "type", "subtype", "page", "per_page", "search", "include", "exclude",
      ].contains(key) {
      return rest_error(400, "rest_invalid_param")
    }
  }
  if !["view", "embed"].contains(query.get("context").unwrap_or("view")) {
    return rest_error(400, "rest_invalid_param")
  }
  let subtypes = query
    .get("subtype")
    .unwrap_or("any")
    .split(",")
    .map(s => s.to_owned())
    .to_array()
  if subtypes.is_empty() ||
    subtypes.length() > 2 ||
    subtypes.any(s => !["any", "category", "post_tag"].contains(s)) ||
    (subtypes.contains("any") && subtypes.length() != 1) {
    return rest_error(400, "rest_invalid_param")
  }
  let search = native_query_text(query.get("search").unwrap_or(""))
  let selected_ids = rest_id_list(query.get("include"))
  let exclude = rest_id_list(query.get("exclude"))
  rest_page_bounds(0, query) |> ignore
  let posts = rest_public_posts(input) catch {
    _ => return rest_error(500, "moonpress_terms_unavailable")
  }
  let terms : Array[RestTerm] = []
  for kind in ["category", "post_tag"] {
    if subtypes.contains("any") || subtypes.contains(kind) {
      for term in rest_public_terms(posts, kind) {
        terms.push(term)
      }
    }
  }
  let selected = terms.filter(term => {
    term.name.to_lower().contains(search) &&
    (selected_ids.is_empty() || selected_ids.contains(term.id)) &&
    !exclude.contains(term.id)
  })
  selected.sort_by(fn(a, b) {
    let compared = a.name.lexical_compare(b.name)
    if compared == 0 {
      a.id.compare(b.id)
    } else {
      compared
    }
  })
  let (start, size, pages) = match rest_page_bounds(selected.length(), query) {
    Some(bounds) => bounds
    None => return rest_error(400, "rest_term_invalid_page_number")
  }
  let rows : Array[Json] = []
  for i = start; i < selected.length() && i < start + size; i = i + 1 {
    let term = selected[i]
    let value = rest_term_value(term, base)
    let url = match value {
      Object(fields) => fields["link"]
      _ => "".to_json()
    }
    rows.push({
      "id": term.id.to_json(),
      "title": escape_html(term.name).to_json(),
      "url": url,
      "type": "term".to_json(),
      "subtype": term.taxonomy.to_json(),
    })
  }
  {
    ..rest_ok(rows.to_json()),
    total: Some(selected.length()),
    pages: Some(pages),
  }
}
