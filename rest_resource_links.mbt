///|
fn rest_article_links(document : Document, base : String) -> Json {
  let plural = if document.kind == "page" { "pages" } else { "posts" }
  let collection = base + "wp-json/wp/v2/" + plural
  let value : Json = {
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
  if document.author > 0 && value is Object(fields) {
    fields["author"] = [
      {
        "href": (base + "wp-json/wp/v2/users/" + document.author.to_string()).to_json(),
      },
    ].to_json()
  }
  value
}
