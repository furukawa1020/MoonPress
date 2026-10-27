///|
fn rest_is_search(path : String) -> Bool {
  path == "/wp-json/wp/v2/search" || path == "/wp-json/wp/v2/search/"
}

///|
fn rest_search(
  input : String,
  query : Map[String, String],
  base : String,
) -> RestResponse raise {
  if query.get("type") == Some("term") {
    return rest_term_search(input, query, base)
  }
  for key, value in query {
    if ![
        "context", "page", "per_page", "search", "include", "exclude", "type", "subtype",
      ].contains(key) ||
      (key == "context" && value != "view" && value != "embed") ||
      (key == "type" && value != "post") {
      return rest_error(400, "rest_invalid_param")
    }
  }
  let subtypes = query
    .get("subtype")
    .unwrap_or("any")
    .split(",")
    .map(s => s.to_owned())
    .to_array()
  if subtypes.is_empty() ||
    subtypes.length() > 2 ||
    subtypes.any(s => !["any", "post", "page"].contains(s)) ||
    (subtypes.contains("any") && subtypes.length() != 1) {
    return rest_error(400, "rest_invalid_param")
  }
  rest_positive(query.get("per_page").unwrap_or("10"), 100) |> ignore
  rest_positive(query.get("page").unwrap_or("1"), 4096) |> ignore
  rest_filter_posts([], query) |> ignore
  let available = rest_public_posts(input) catch {
    _ => return rest_error(500, "moonpress_content_unavailable")
  }
  let posts = rest_filter_posts(
    available.filter(post => {
      subtypes.contains("any") || subtypes.contains(post.document.kind)
    }),
    query,
  )
  let (start, size, pages) = match rest_page_bounds(posts.length(), query) {
    Some(bounds) => bounds
    None => return rest_error(400, "rest_post_invalid_page_number")
  }
  rest_order_posts(posts, query)
  let values : Array[Json] = []
  for i = start; i < posts.length() && i < start + size; i = i + 1 {
    let post = posts[i]
    values.push({
      "id": post.document.wp_id.unwrap().to_json(),
      "title": escape_html(post.document.title).to_json(),
      "url": (base +
      url_component(post.document.slug.unwrap_or(post.stem) + ".html")).to_json(),
      "type": "post".to_json(),
      "subtype": post.document.kind.to_json(),
    })
  }
  {
    ..rest_ok(values.to_json()),
    total: Some(posts.length()),
    pages: Some(pages),
  }
}
