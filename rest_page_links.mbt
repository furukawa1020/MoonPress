///|
fn rest_page_links(
  target : String,
  base : String,
  result : RestResponse,
) -> String? raise {
  let (path, original) = rest_target(target)
  if result.code != 200 ||
    (
      !rest_is_collection(path) &&
      !rest_is_search(path) &&
      !rest_users_collection(path) &&
      rest_wp_comment_id(path) != Some(0) &&
      !(rest_wp_term_target(path) is Some((_, 0)))
    ) {
    return None
  }
  let pages = result.pages.unwrap_or(0)
  let terms = rest_wp_term_target(path) is Some((_, 0))
  let page = if terms {
    let (start, size, _) = rest_term_page_bounds(
      result.total.unwrap_or(0),
      original,
      offsets=rest_wp_term_target(path) is Some(("post_tag", 0)),
    )
    (start + size - 1) / size + 1
  } else {
    rest_positive(original.get("page").unwrap_or("1"), 4096)
  }
  let previous = if terms && page - 1 > pages { pages } else { page - 1 }
  let links : Array[String] = []
  for (next, rel) in [(previous, "prev"), (page + 1, "next")] {
    if next < 1 || next > pages {
      continue
    }
    let query = original.copy()
    query["page"] = next.to_string()
    let keys = query.keys().to_array()
    keys.sort()
    let pairs = keys.map(key => {
      url_component(key) + "=" + url_component(query[key])
    })
    links.push(
      "<" +
      base +
      path[1:].to_owned() +
      "?" +
      pairs.join("&") +
      ">; rel=\"" +
      rel +
      "\"",
    )
  }
  if links.is_empty() {
    None
  } else {
    Some(links.join(", "))
  }
}
