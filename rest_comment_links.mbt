///|
fn rest_comment_links(
  c : NativeComment,
  articles : Array[RestPost],
  base : String,
) -> Json {
  let collection = base + "wp-json/wp/v2/comments"
  let fields : Map[String, Json] = Map([
    (
      "self",
      [{ "href": (collection + "/" + c.id.to_string()).to_json() }].to_json(),
    ),
    ("collection", [{ "href": collection.to_json() }].to_json()),
    (
      "children",
      [{ "href": (collection + "?parent=" + c.id.to_string()).to_json() }].to_json(),
    ),
  ])
  if c.parent is Some(parent) {
    fields["up"] = [
      { "href": (collection + "/" + parent.to_string()).to_json() },
    ].to_json()
  }
  for article in articles {
    if article.document.wp_id == Some(c.post) {
      let plural = if article.document.kind == "page" {
        "pages"
      } else {
        "posts"
      }
      fields["in-reply-to"] = [
        {
          "href": (base + "wp-json/wp/v2/" + plural + "/" + c.post.to_string()).to_json(),
        },
      ].to_json()
    }
  }
  Json::object(fields)
}
