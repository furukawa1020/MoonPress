///|
fn rest_article_links(document : Document, base : String) -> Json {
  let plural = if document.kind == "page" { "pages" } else { "posts" }
  let collection = base + "wp-json/wp/v2/" + plural
  {
    "self": [
      {
        "href": (collection + "/" + document.wp_id.unwrap().to_string()).to_json(),
      },
    ].to_json(),
    "collection": [{ "href": collection.to_json() }].to_json(),
    "about": [
      { "href": (base + "wp-json/wp/v2/types/" + document.kind).to_json() },
    ].to_json(),
  }
}
