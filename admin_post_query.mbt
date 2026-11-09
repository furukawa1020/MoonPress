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
  for
    key in [
      "q", "state", "page", "kind", "sort", "per_page", "tag", "visibility", "after",
    ] {
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
    if ![
        "q", "state", "page", "kind", "sort", "per_page", "tag", "visibility", "after",
      ].contains(key) {
      raise InvalidInput("Unknown post query field: " + key)
    }
  }
  let query = native_query_text(fields.get("q").unwrap_or(""))
  let sort = fields.get("sort").unwrap_or("source")
  if !["source", "date_desc", "date_asc", "title", "title_desc", "source_desc"].contains(
      sort,
    ) {
    raise InvalidInput("Invalid post sort")
  }
  let tag = fields.get("tag").unwrap_or("")
  if @utf8.encode(tag).length() > 96 {
    raise InvalidInput("Invalid tag filter")
  }
  let visibility = fields.get("visibility").unwrap_or("all")
  if !["all", "listed", "unlisted"].contains(visibility) {
    raise InvalidInput("Invalid listing filter")
  }
  let after = fields.get("after").unwrap_or("")
  if !after.is_empty() && !valid_publication_date(after) {
    raise InvalidInput("Invalid after date")
  }
  let matches = posts.filter(post => {
    (
      query.is_empty() ||
      post.title.to_lower().contains(query) ||
      post.source.to_lower().contains(query) ||
      post.tags.any(tag => tag.to_lower().contains(query))
    ) &&
    (tag.is_empty() || post.tags.contains(tag)) &&
    (visibility == "all" || post.listed == (visibility == "listed")) &&
    (after.is_empty() || (post.date is Some(date) && date >= after))
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
      "title" => a.title.to_lower().lexical_compare(b.title.to_lower())
      "title_desc" => b.title.to_lower().lexical_compare(a.title.to_lower())
      "source_desc" => b.source.compare(a.source)
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
  let size = rest_positive(fields.get("per_page").unwrap_or("20"), 100)
  let pages = if total == 0 { 1 } else { (total - 1) / size + 1 }
  if page > pages {
    raise InvalidInput("Page exceeds available pages")
  }
  let start = (page - 1) * size
  let end = if total - start < size { total } else { start + size }
  (start, end, pages)
}
