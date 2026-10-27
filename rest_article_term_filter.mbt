///|
fn rest_filter_document_terms(
  document : Document,
  query : Map[String, String],
) -> Bool raise {
  let clauses : Array[Bool] = []
  for (plural, kind) in [("categories", "category"), ("tags", "post_tag")] {
    let ids = rest_document_term_ids(document, kind)
    let include = rest_id_list(query.get(plural))
    let exclude = rest_id_list(query.get(plural + "_exclude"))
    if !include.is_empty() {
      clauses.push(include.any(id => ids.contains(id)))
    }
    if !exclude.is_empty() {
      clauses.push(!exclude.any(id => ids.contains(id)))
    }
  }
  if query.get("tax_relation") == Some("OR") && !clauses.is_empty() {
    clauses.any(value => value)
  } else {
    clauses.all(value => value)
  }
}

///|
fn rest_validate_term_filters(query : Map[String, String]) -> Unit raise {
  if !["AND", "OR"].contains(query.get("tax_relation").unwrap_or("AND")) {
    raise InvalidInput("Invalid taxonomy relation")
  }
  for name in ["categories", "tags", "categories_exclude", "tags_exclude"] {
    rest_id_list(query.get(name)) |> ignore
  }
}
