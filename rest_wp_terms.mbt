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
fn rest_term_value(term : RestTerm, base : String) -> Json {
  let value : Json = {
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
  value
}

///|
fn rest_wp_terms(
  input : String,
  path : String,
  query : Map[String, String],
  base : String,
) -> RestResponse raise {
  for key, _ in query {
    if !["include", "exclude"].contains(key) {
      return rest_error(400, "rest_invalid_param")
    }
  }
  let include = rest_id_list(query.get("include"))
  let exclude = rest_id_list(query.get("exclude"))
  let (kind, id) = rest_wp_term_target(path).unwrap()
  let available = rest_public_terms(rest_public_posts(input), kind) catch {
    _ => return rest_error(500, "moonpress_terms_unavailable")
  }
  if id > 0 && !query.is_empty() {
    return rest_error(400, "rest_invalid_param")
  }
  let terms = available.filter(term => {
    (include.is_empty() || include.contains(term.id)) &&
    !exclude.contains(term.id)
  })
  if id > 0 {
    for term in terms {
      if term.id == id {
        return rest_ok(rest_term_value(term, base))
      }
    }
    return rest_error(404, "rest_term_invalid")
  }
  let rows : Array[Json] = []
  for i = 0; i < terms.length() && i < 10; i = i + 1 {
    rows.push(rest_term_value(terms[i], base))
  }
  {
    ..rest_ok(rows.to_json()),
    total: Some(terms.length()),
    pages: Some((terms.length() + 9) / 10),
  }
}
