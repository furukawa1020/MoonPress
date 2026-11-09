///|
fn admin_post_url(
  fields : Map[String, String],
  changes : Map[String, String],
) -> String {
  let selected = fields.copy()
  for key, value in changes {
    selected[key] = value
  }
  let parts : Array[String] = []
  for key in ["q", "state", "page", "kind", "sort"] {
    if selected.get(key) is Some(value) {
      parts.push(key + "=" + url_component(value))
    }
  }
  if parts.is_empty() {
    "/"
  } else {
    "/?" + parts.join("&amp;")
  }
}

///|
fn admin_post_scope(
  posts : Array[PostSummary],
  fields : Map[String, String],
) -> Array[PostSummary] raise {
  for key, _ in fields {
    if !["q", "state", "page", "kind", "sort"].contains(key) {
      raise InvalidInput("Unknown post query field: " + key)
    }
  }
  let query = native_query_text(fields.get("q").unwrap_or(""))
  let sort = fields.get("sort").unwrap_or("source")
  if !["source", "date_desc", "date_asc"].contains(sort) {
    raise InvalidInput("Invalid post sort")
  }

  let matches = posts.filter(post => {
    query.is_empty() ||
    post.title.to_lower().contains(query) ||
    post.source.to_lower().contains(query) ||
    post.tags.any(tag => tag.to_lower().contains(query))
  })
  matches.sort_by(fn(a, b) {
    let primary = match sort {
      "date_asc" | "date_desc" =>
        match (a.date, b.date) {
          (None, None) => 0
          (None, Some(_)) => 1
          (Some(_), None) => -1
          (Some(x), Some(y)) =>
            if sort == "date_desc" {
              y.compare(x)
            } else {
              x.compare(y)
            }
        }
      _ => 0
    }
    if primary == 0 {
      a.source.compare(b.source)
    } else {
      primary
    }
  })
  matches
}

///|
fn admin_post_window(
  total : Int,
  fields : Map[String, String],
) -> (Int, Int, Int) raise {
  let page = admin_page_number(fields.get("page").unwrap_or("1"))
  admin_page_bounds(total, page)
}
