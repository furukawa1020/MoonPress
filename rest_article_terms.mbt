///|
fn rest_document_term_ids(document : Document, kind : String) -> Array[Int] {
  if document.kind != "post" {
    return []
  }
  let names = if kind == "category" {
    document.categories
  } else {
    document.tags
  }
  let ids = names.map(name => rest_term_id(kind, name))
  ids.sort()
  ids
}

///|
fn rest_article_term_ids(value : Json, document : Document) -> Json {
  if document.kind == "post" && value is Object(fields) {
    fields["categories"] = rest_document_term_ids(document, "category").to_json()
    fields["tags"] = rest_document_term_ids(document, "post_tag").to_json()
  }
  value
}

///|
fn rest_validate_term_inventory(posts : Array[RestPost]) -> Unit raise {
  let used : Map[Int, Bool] = Map([])
  for kind in ["category", "post_tag"] {
    for term in rest_public_terms(posts, kind) {
      if used.contains(term.id) {
        raise InvalidInput("Public taxonomy identity collision")
      }
      used[term.id] = true
    }
  }
}
