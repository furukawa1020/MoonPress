///|
fn rest_target_hints(value : Json, base : String) -> Json {
  match value {
    Array(items) => items.map(item => rest_target_hints(item, base)).to_json()
    Object(fields) => {
      if fields.get("_links") is Some(Object(links)) &&
        links.get("self") is Some(Array(items)) {
        for item in items {
          if item is Object(link) &&
            link.get("href") is Some(String(href)) &&
            href.has_prefix(base + "wp-json/wp/v2/") {
            let target = rest_target("/" + href[base.length():].to_owned()) catch {
              _ => continue
            }
            if rest_methods(target.0) is Some(methods) {
              link["targetHints"] = { "allow": methods.to_json() }
            }
          }
        }
      }
      value
    }
    _ => value
  }
}
