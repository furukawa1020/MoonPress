///|
priv struct RestTerm {
  id : Int
  name : String
  slug : String
  taxonomy : String
  count : Int
}

///|
fn rest_term_id(kind : String, name : String) -> Int {
  let digest = digest_text(kind + "\n" + name)
  let mut id = 0
  let mut index = 0
  for c in digest[:8] {
    let digit = if c >= 'a' {
      c.to_int() - 'a'.to_int() + 10
    } else {
      c.to_int() - '0'.to_int()
    }
    id = id * 16 + (if index == 0 { digit % 8 } else { digit })
    index += 1
  }
  if id == 0 {
    1
  } else {
    id
  }
}

///|
fn rest_term_slug(name : String) -> String {
  "term-" + @crypto.bytes_to_hex_string(@utf8.encode(name))
}

///|
fn rest_wp_term_target(path : String) -> (String, Int)? {
  for (plural, kind) in [("categories", "category"), ("tags", "post_tag")] {
    let prefix = "/wp-json/wp/v2/" + plural
    if path == prefix || path == prefix + "/" {
      return Some((kind, 0))
    }
    if path.has_prefix(prefix + "/") {
      let tail = path[prefix.length() + 1:].trim_end(chars="/").to_owned()
      let id = rest_positive(tail, 2147483647) catch { _ => return None }
      return Some((kind, id))
    }
  }
  None
}

///|
fn rest_public_terms(
  posts : Array[RestPost],
  kind : String,
) -> Array[RestTerm] raise {
  let counts : Map[String, Int] = Map([])
  for post in posts {
    if post.document.kind != "post" {
      continue
    }
    let names = if kind == "category" {
      post.document.categories
    } else {
      post.document.tags
    }
    for name in names {
      counts[name] = counts.get(name).unwrap_or(0) + 1
      if counts.length() > 4096 {
        raise InvalidInput("Public term limit")
      }
    }
  }
  let terms : Array[RestTerm] = []
  let used : Map[Int, Bool] = Map([])
  for name, count in counts {
    let id = rest_term_id(kind, name)
    if used.contains(id) {
      raise InvalidInput("Public term identity collision")
    }
    used[id] = true
    terms.push({ id, name, slug: rest_term_slug(name), taxonomy: kind, count, })
  }
  terms.sort_by(fn(a, b) { a.name.lexical_compare(b.name) })
  terms
}

///|
fn rest_term_value(
  term : RestTerm,
  base : String,
  context? : String = "view",
) -> Json {
  let value : Json = {
    "_links": rest_term_links(term, base),
    "id": term.id.to_json(),
    "name": escape_html(term.name).to_json(),
    "slug": term.slug.to_json(),
    "taxonomy": term.taxonomy.to_json(),
    "count": term.count.to_json(),
    "description": "".to_json(),
    "link": (base +
    (if term.taxonomy == "category" {
      category_filename(term.name)
    } else {
      tag_filename(term.name)
    })).to_json(),
  }
  if term.taxonomy == "category" && value is Object(fields) {
    fields["parent"] = (0).to_json()
  }
  if context == "embed" {
    rest_project(value, ["id", "name", "slug", "taxonomy", "link", "_links"])
  } else {
    value
  }
}

///|
fn rest_wp_terms(
  input : String,
  path : String,
  query : Map[String, String],
  base : String,
) -> RestResponse raise {
  for key, _ in query {
    if ![
        "include", "exclude", "slug", "orderby", "search", "post", "parent", "hide_empty",
        "order", "page", "per_page", "offset", "context",
      ].contains(key) {
      return rest_error(400, "rest_invalid_param")
    }
  }
  if !["view", "embed"].contains(query.get("context").unwrap_or("view")) {
    return rest_error(400, "rest_invalid_param")
  }
  rest_term_page_bounds(0, query) |> ignore
  let post_id = query.get("post").map(value => rest_positive(value, 2147483647))
  let parent = rest_nonnegative(query.get("parent").unwrap_or("0"), 2147483647)
  if !["true", "false", "1", "0"].contains(
      query.get("hide_empty").unwrap_or("false"),
    ) {
    return rest_error(400, "rest_invalid_param")
  }
  let search = native_query_text(query.get("search").unwrap_or(""))
  let slugs = rest_term_slugs(query.get("slug"))
  let orderby = query.get("orderby").unwrap_or("name")
  let order = query.get("order").unwrap_or("asc")
  if !["name", "slug", "id", "count", "include", "include_slugs"].contains(
      orderby,
    ) ||
    !["asc", "desc"].contains(order) ||
    (orderby == "include_slugs" && slugs.is_empty()) {
    return rest_error(400, "rest_invalid_param")
  }
  let selected_ids = rest_id_list(query.get("include"))
  let exclude = rest_id_list(query.get("exclude"))
  if orderby == "include" && selected_ids.is_empty() {
    return rest_error(400, "rest_invalid_param")
  }
  let (kind, id) = rest_wp_term_target(path).unwrap()
  if kind != "category" && query.contains("parent") {
    return rest_error(400, "rest_invalid_param")
  }
  let posts = rest_public_posts(input) catch {
    _ => return rest_error(500, "moonpress_terms_unavailable")
  }
  let available = rest_public_terms(posts, kind) catch {
    _ => return rest_error(500, "moonpress_terms_unavailable")
  }
  let selected_names : Array[String] = []
  if post_id is Some(selected) {
    for post in posts {
      if post.document.kind == "post" && post.document.wp_id == Some(selected) {
        for
          name in (if kind == "category" {
            post.document.categories
          } else {
            post.document.tags
          }) {
          selected_names.push(name)
        }
      }
    }
  }
  if id > 0 && query.keys().any(key => key != "context") {
    return rest_error(400, "rest_invalid_param")
  }
  let terms = available.filter(term => {
    (selected_ids.is_empty() || selected_ids.contains(term.id)) &&
    (!selected_ids.is_empty() || !exclude.contains(term.id)) &&
    (slugs.is_empty() || slugs.contains(term.slug)) &&
    term.name.to_lower().contains(search) &&
    parent == 0 &&
    (post_id is None || selected_names.contains(term.name))
  })
  let ranks : Map[Int, Int] = Map([])
  for i = 0; i < selected_ids.length(); i = i + 1 {
    ranks[selected_ids[i]] = i
  }
  let slug_ranks : Map[String, Int] = Map([])
  for i = 0; i < slugs.length(); i = i + 1 {
    slug_ranks[slugs[i]] = i
  }
  terms.sort_by(fn(a, b) {
    let compared = match orderby {
      "include" => ranks[a.id].compare(ranks[b.id])
      "include_slugs" => slug_ranks[a.slug].compare(slug_ranks[b.slug])
      "id" => a.id.compare(b.id)
      "count" => a.count.compare(b.count)
      "slug" => a.slug.lexical_compare(b.slug)
      _ => a.name.lexical_compare(b.name)
    }
    let compared = if compared == 0 { a.id.compare(b.id) } else { compared }
    if order == "asc" {
      compared
    } else {
      0 - compared
    }
  })
  if id > 0 {
    for term in terms {
      if term.id == id {
        return rest_ok(
          rest_term_value(
            term,
            base,
            context=query.get("context").unwrap_or("view"),
          ),
        )
      }
    }
    return rest_error(404, "rest_term_invalid")
  }
  let (start, size, pages) = rest_term_page_bounds(
    terms.length(),
    query,
    offsets=kind == "post_tag",
  )
  let rows : Array[Json] = []
  for i = start; i < terms.length() && i < start + size; i = i + 1 {
    rows.push(
      rest_term_value(
        terms[i],
        base,
        context=query.get("context").unwrap_or("view"),
      ),
    )
  }
  {
    ..rest_ok(rows.to_json()),
    total: Some(terms.length()),
    pages: Some(pages),
  }
}
