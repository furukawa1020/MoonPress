///|
fn rest_validate_collection(
  query : Map[String, String],
  edit : Bool,
) -> Unit raise {
  for key, value in query {
    if ![
        "context", "per_page", "page", "slug", "order", "orderby", "search", "include",
        "exclude", "author", "author_exclude", "offset", "status",
      ].contains(key) ||
      (key == "context" && value != (if edit { "edit" } else { "view" })) ||
      (key == "order" && value != "asc" && value != "desc") ||
      (
        key == "orderby" &&
        !["date", "id", "title", "slug", "include"].contains(value)
      ) {
      raise InvalidInput("Unsupported collection query")
    }
  }
  let statuses = query
    .get("status")
    .unwrap_or("publish")
    .split(",")
    .map(s => s.to_owned())
    .to_array()
  if statuses.is_empty() ||
    statuses.length() > 3 ||
    statuses.any(s => !["publish", "draft", "future", "any"].contains(s)) ||
    (!edit && statuses != ["publish"]) {
    raise InvalidInput("Unsupported status filter")
  }
  rest_filter_posts([], query) |> ignore
  rest_positive(query.get("per_page").unwrap_or("10"), 100) |> ignore
  rest_positive(query.get("page").unwrap_or("1"), 4096) |> ignore
  rest_nonnegative(query.get("offset").unwrap_or("0"), 409600) |> ignore
}

///|
fn rest_is_collection(path : String) -> Bool {
  [
    "/wp-json/wp/v2/posts", "/wp-json/wp/v2/pages", "/wp-json/wp/v2/posts/", "/wp-json/wp/v2/pages/",
  ].contains(path)
}

///|
fn rest_edit_collection(
  input : String,
  path : String,
  query : Map[String, String],
  base : String,
  authorization : String?,
) -> RestResponse raise {
  rest_validate_collection(query, true) catch {
    _ => return rest_error(400, "rest_invalid_param")
  }
  rest_with_access(input, authorization, fn(principal, directory) raise {
    let kind = if path.has_prefix("/wp-json/wp/v2/posts") {
      "post"
    } else {
      "page"
    }
    if !role_capabilities(principal.role).contains(
        "edit_" + (if kind == "page" { "pages" } else { "posts" }),
      ) {
      return rest_error(403, "rest_cannot_edit")
    }
    let statuses = query
      .get("status")
      .unwrap_or("publish")
      .split(",")
      .map(s => s.to_owned())
      .to_array()
    let instant = authoring_time()
    let allowed : Array[RestPost] = []
    for post in rest_all_posts_at(input, directory) {
      let doc = post.document
      let status = if doc.draft {
        "draft"
      } else if !publication_due(doc.publish_at, instant) {
        "future"
      } else {
        "publish"
      }
      if doc.kind == kind &&
        (statuses.contains("any") || statuses.contains(status)) &&
        role_can_edit(
          principal.role,
          principal.id,
          doc.author,
          kind,
          !doc.draft,
        ) {
        allowed.push(post)
      }
    }
    rest_collection_result(rest_filter_posts(allowed, query), query, base, true, instant~)
  })
}

///|
fn rest_collection_result(
  posts : Array[RestPost],
  query : Map[String, String],
  base : String,
  edit : Bool,
  instant? : Int64 = authoring_time(),
) -> RestResponse raise {
  let size = rest_positive(query.get("per_page").unwrap_or("10"), 100)
  let page = rest_positive(query.get("page").unwrap_or("1"), 4096)
  rest_order_posts(posts, query)
  let offset = rest_nonnegative(query.get("offset").unwrap_or("0"), 409600)
  let total = posts.length()
  let pages = (total + size - 1) / size
  if page > pages && page != 1 {
    return rest_error(400, "rest_post_invalid_page_number")
  }
  let values : Array[Json] = []
  let start = if query.contains("offset") { offset } else { (page - 1) * size }
  for i = start; i < total && i < start + size; i = i + 1 {
    values.push(
      if edit {
        rest_edit_value(posts[i].document, posts[i].stem, base, posts[i].digest, instant~)
      } else {
        rest_post_value(posts[i].document, posts[i].stem, base)
      },
    )
  }
  {
    etag: None,
    code: 200,
    value: values.to_json(),
    total: Some(total),
    pages: Some(pages),
  }
}
