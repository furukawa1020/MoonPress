///|
fn rest_search(
  input : String,
  query : Map[String, String],
  base : String,
) -> RestResponse raise {
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
  let result = rest_collection_result(posts, query, base, false)
  if result.code != 200 {
    return result
  }
  let values : Array[Json] = []
  match result.value {
    Array(items) =>
      for item in items {
        match item {
          Object(fields) => {
            let title = match fields.get("title") {
              Some(Object(title)) => title.get("rendered").unwrap()
              _ => raise InvalidInput("Invalid article title")
            }
            values.push({
              "id": fields.get("id").unwrap(),
              "title": title,
              "url": fields.get("link").unwrap(),
              "type": "post".to_json(),
              "subtype": fields.get("type").unwrap(),
            })
          }
          _ => raise InvalidInput("Invalid article result")
        }
      }
    _ => raise InvalidInput("Invalid search result")
  }
  { ..result, value: values.to_json(), }
}
