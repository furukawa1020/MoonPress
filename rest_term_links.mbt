///|
fn rest_term_links(term : RestTerm, base : String) -> Json {
  let plural = if term.taxonomy == "category" { "categories" } else { "tags" }
  let collection = base + "wp-json/wp/v2/" + plural
  {
    "curies": [
      {
        "name": "wp".to_json(),
        "href": "https://api.w.org/{rel}".to_json(),
        "templated": true.to_json(),
      },
    ].to_json(),
    "self": [{ "href": (collection + "/" + term.id.to_string()).to_json() }].to_json(),
    "collection": [{ "href": collection.to_json() }].to_json(),
    "about": [
      { "href": (base + "wp-json/wp/v2/taxonomies/" + term.taxonomy).to_json() },
    ].to_json(),
    "wp:post_type": [
      {
        "href": (base +
        "wp-json/wp/v2/posts?" +
        plural +
        "=" +
        term.id.to_string()).to_json(),
      },
    ].to_json(),
  }
}
