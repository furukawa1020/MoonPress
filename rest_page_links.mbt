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
      rest_wp_comment_id(path) != Some(0)
    ) {
    return None
  }
  let pages = result.pages.unwrap_or(0)
  let page = rest_positive(original.get("page").unwrap_or("1"), 4096)
  let links : Array[String] = []
  for (next, rel) in [(page - 1, "prev"), (page + 1, "next")] {
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
