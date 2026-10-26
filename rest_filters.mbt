///|
fn rest_nonnegative(value : String, maximum : Int) -> Int raise {
  if value == "0" {
    0
  } else {
    rest_positive(value, maximum)
  }
}

///|
fn rest_id_list(value : String?) -> Array[Int] raise {
  let ids : Array[Int] = []
  if value is Some(value) && !value.is_empty() {
    for part in value.split(",") {
      let id = rest_positive(part.trim().to_owned(), 2147483647)
      if !ids.contains(id) {
        ids.push(id)
      }
      if ids.length() > 100 {
        raise InvalidInput("ID filter exceeds 100 entries")
      }
    }
  }
  ids
}

///|
fn rest_filter_posts(
  posts : Array[RestPost],
  query : Map[String, String],
) -> Array[RestPost] raise {
  let before = query.get("before").map(value => rest_date_bound(value))
  let after = query.get("after").map(value => rest_date_bound(value))
  let category = query
    .get("moonpress_category")
    .map(value => rest_named_terms([value.to_json()])[0])
  let tag = query
    .get("moonpress_tag")
    .map(value => rest_named_terms([value.to_json()])[0])
  let selected_ids = rest_id_list(query.get("include"))
  let exclude = rest_id_list(query.get("exclude"))
  let authors = rest_id_list(query.get("author"))
  let others = rest_id_list(query.get("author_exclude"))
  let columns = query
    .get("search_columns")
    .unwrap_or("")
    .split(",")
    .map(s => s.to_owned())
    .to_array()
    .filter(s => !s.is_empty())
  if columns.length() > 3 ||
    columns.any(s => !["post_title", "post_content", "post_excerpt"].contains(s)) {
    raise InvalidInput("Invalid search columns")
  }
  let search = query.get("search").unwrap_or("").trim().to_owned().to_lower()
  if search.length() > 256 {
    raise InvalidInput("Search exceeds 256 characters")
  }
  let normalized = StringBuilder()
  for c in search {
    normalized.write_char(if c.is_whitespace() { ' ' } else { c })
  }
  let terms = normalized
    .to_string()
    .split(" ")
    .map(term => term.to_owned())
    .to_array()
    .filter(term => !term.is_empty())
  if terms.length() > 16 {
    raise InvalidInput("Search exceeds 16 terms")
  }
  let slugs = query
    .get("slug")
    .unwrap_or("")
    .split(",")
    .map(slug => slug.to_owned())
    .to_array()
  if query.contains("slug") &&
    (slugs.length() > 100 || slugs.any(slug => !valid_slug(slug))) {
    raise InvalidInput("Invalid slug filter")
  }
  if query.get("orderby") == Some("include") && selected_ids.is_empty() {
    raise InvalidInput("Include ordering needs IDs")
  }
  posts.filter(post => {
    let doc = post.document
    let id = doc.wp_id.unwrap()
    let haystack = if terms.is_empty() {
      ""
    } else {
      ((if columns.is_empty() || columns.contains("post_title") {
        doc.title
      } else {
        ""
      }) +
      "\n" +
      (if columns.is_empty() || columns.contains("post_excerpt") {
        doc.description
      } else {
        ""
      }) +
      "\n" +
      (if columns.is_empty() || columns.contains("post_content") {
        doc.body
      } else {
        ""
      })).to_lower()
    }
    (before is None || rest_post_timestamp(doc) < before.unwrap()) &&
    (after is None || rest_post_timestamp(doc) > after.unwrap()) &&
    (category is None || doc.categories.contains(category.unwrap())) &&
    (tag is None || doc.tags.contains(tag.unwrap())) &&
    (selected_ids.is_empty() || selected_ids.contains(id)) &&
    !exclude.contains(id) &&
    (authors.is_empty() || authors.contains(doc.author)) &&
    !others.contains(doc.author) &&
    (!query.contains("slug") || slugs.contains(doc.slug.unwrap_or(post.stem))) &&
    (terms.is_empty() || terms.all(term => haystack.contains(term)))
  })
}

///|
fn rest_order_posts(
  posts : Array[RestPost],
  query : Map[String, String],
) -> Unit raise {
  let orderby = query.get("orderby").unwrap_or("date")
  let ascending = query.get("order") == Some("asc")
  let selected_ids = rest_id_list(query.get("include"))
  let ranks : Map[Int, Int] = Map([])
  for i = 0; i < selected_ids.length(); i = i + 1 {
    ranks[selected_ids[i]] = i
  }
  posts.sort_by(fn(a, b) {
    let compared = match orderby {
      "id" => a.document.wp_id.unwrap().compare(b.document.wp_id.unwrap())
      "title" => a.document.title.compare(b.document.title)
      "slug" =>
        a.document.slug
        .unwrap_or(a.stem)
        .compare(b.document.slug.unwrap_or(b.stem))
      "include" =>
        ranks
        .get(a.document.wp_id.unwrap())
        .unwrap_or(0)
        .compare(ranks.get(b.document.wp_id.unwrap()).unwrap_or(0))
      _ =>
        a.document.publish_at
        .unwrap_or(a.document.date.unwrap_or("1970-01-01") + "T00:00:00Z")
        .compare(
          b.document.publish_at.unwrap_or(
            b.document.date.unwrap_or("1970-01-01") + "T00:00:00Z",
          ),
        )
    }
    let compared = if compared == 0 {
      a.document.wp_id.unwrap().compare(b.document.wp_id.unwrap())
    } else {
      compared
    }
    if ascending || orderby == "include" {
      compared
    } else {
      0 - compared
    }
  })
}

///|
test "REST filters bound IDs and keep include order" {
  assert_eq(rest_id_list(Some("3,2,3")), [3, 2])
  assert_eq(rest_id_list(Some("")), [])
  let refused = try {
    rest_id_list(Some("1,0")) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(refused)
}

///|
test "REST search counts every Unicode whitespace-separated term" {
  let refused = try {
    rest_filter_posts([], Map([("search", "x\t".repeat(17))])) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(refused)
}
