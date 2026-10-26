///|
fn rest_article_context(value : Json, query : Map[String, String]) -> Json {
  if query.get("context") == Some("embed") {
    rest_project(value, [
      "id", "date", "slug", "type", "link", "title", "excerpt", "author",
    ])
  } else {
    value
  }
}
