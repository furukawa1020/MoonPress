///|
fn admin_comment_url(
  query : Map[String, String],
  changes : Map[String, String],
) -> String {
  let selected = query.copy()
  for key, value in changes {
    selected[key] = value
  }
  let parts : Array[String] = []
  for
    key in [
      "status", "post", "author", "parent", "search", "order", "per_page", "page",
    ] {
    if selected.get(key) is Some(value) {
      parts.push(key + "=" + url_component(value))
    }
  }
  if parts.is_empty() {
    "/comments"
  } else {
    "/comments?" + parts.join("&amp;")
  }
}

///|
fn admin_comments(
  input : String,
  raw_query : Map[String, String],
) -> String raise {
  let query = raw_query.copy()
  for key, _ in query {
    if ![
        "status", "page", "search", "parent", "post", "author", "order", "per_page",
      ].contains(key) {
      raise InvalidInput("Invalid comment query")
    }
  }
  for key in ["post", "author"] {
    if query.get(key) == Some("") {
      query.remove(key)
    }
  }
  let status = query.get("status").unwrap_or("hold")
  if !["any", "hold", "approved", "spam", "trash"].contains(status) {
    raise InvalidInput("Invalid comment status")
  }
  let parent = query
    .get("parent")
    .map(value => rest_nonnegative(value, 2147483647))
  let post = query.get("post").map(value => rest_positive(value, 2147483647))
  let author = query
    .get("author")
    .map(value => rest_positive(value, 2147483647))
  let order = query.get("order").unwrap_or("asc")
  if !["asc", "desc"].contains(order) {
    raise InvalidInput("Invalid comment order")
  }
  rest_positive(query.get("per_page").unwrap_or("10"), 100) |> ignore
  let search = native_query_text(query.get("search").unwrap_or(""))
  let state = comment_snapshot(input)
  let scoped = state.rows.filter(row => {
    (parent is None || row.comment.parent.unwrap_or(0) == parent.unwrap()) &&
    (post is None || row.comment.post == post.unwrap()) &&
    (author is None || row.comment.author == author.unwrap()) &&
    (row.comment.content + "\n" + row.comment.author_name)
    .to_lower()
    .contains(search)
  })
  let rows = scoped.filter(row => {
    status == "any" || row.comment.status == status
  })
  if order == "desc" {
    rows.sort_by(fn(a, b) { b.comment.id.compare(a.comment.id) })
  }
  let (start, size, pages) = match rest_page_bounds(rows.length(), query) {
    Some(value) => value
    None => raise InvalidInput("Comment page out of range")
  }
  let articles = admin_comment_posts(input)
  let out = StringBuilder()
  out.write_string(
    "<p><!--mp:ja-->ローカル管理者用のコメント一覧です。未承認の本文は公開しません。<!--mp:en-->Local operator comment inventory. Pending text remains unpublished.<!--mp:end--></p><p class=\"comment-filters\">",
  )
  for filter in ["hold", "approved", "spam", "trash", "any"] {
    let count = scoped
      .filter(row => filter == "any" || row.comment.status == filter)
      .length()
    out.write_string(
      "<a href=\"" +
      admin_comment_url(query, Map([("status", filter), ("page", "1")])) +
      "\"" +
      "" +
      ">" +
      filter +
      " (\{count})</a> · ",
    )
  }
  out.write_string("</p><form method=\"get\" action=\"/comments\">")
  out.write_string(admin_hidden("status", status))
  if parent is Some(value) {
    out.write_string(admin_hidden("parent", value.to_string()))
  }
  out.write_string(
    "<label><!--mp:ja-->記事ID<!--mp:en-->Article ID<!--mp:end--><input type=\"number\" name=\"post\" min=\"1\" max=\"2147483647\" value=\"" +
    escape_html(query.get("post").unwrap_or("")) +
    "\"></label>",
  )
  out.write_string(
    "<label><!--mp:ja-->投稿者ID<!--mp:en-->Author ID<!--mp:end--><input type=\"number\" name=\"author\" min=\"1\" max=\"2147483647\" value=\"" +
    escape_html(query.get("author").unwrap_or("")) +
    "\"></label>",
  )
  out.write_string(
    "<label><!--mp:ja-->並び順<!--mp:en-->Order<!--mp:end--><select name=\"order\">",
  )
  for value in ["asc", "desc"] {
    let label = if value == "asc" {
      admin_i18n("古い順", "Oldest first")
    } else {
      admin_i18n("新しい順", "Newest first")
    }
    out.write_string(
      "<option value=\"" +
      value +
      "\"" +
      (if order == value { " selected" } else { "" }) +
      ">" +
      label +
      "</option>",
    )
  }
  out.write_string("</select></label>")
  out.write_string(
    "<label><!--mp:ja-->表示件数<!--mp:en-->Items per page<!--mp:end--><input type=\"number\" name=\"per_page\" min=\"1\" max=\"100\" required value=\"" +
    size.to_string() +
    "\"></label>",
  )
  out.write_string(
    "<label><!--mp:ja-->コメントを探す<!--mp:en-->Search comments<!--mp:end--><input name=\"search\" maxlength=\"256\" value=\"" +
    escape_html(query.get("search").unwrap_or("")) +
    "\"></label><button><!--mp:ja-->探す<!--mp:en-->Search<!--mp:end--></button></form>",
  )

  out.write_string("<p>\{rows.length()} comments</p>")

  out.write_string(admin_table_start("Comments"))
  out.write_string(
    "<thead><tr><th>ID</th><th>Post</th><th>Author</th><th>Status</th><th>Text</th><th>Parent</th><th>Created (UTC)</th></tr></thead><tbody>",
  )
  for i = start; i < rows.length() && i < start + size; i = i + 1 {
    let c = rows[i].comment
    out.write_string(
      "<tr><td><a href=\"/comment?id=\{c.id}\">\{c.id}</a></td><td>" +
      admin_comment_post(c.post, articles) +
      "</td><td>" +
      escape_html(c.author_name) +
      "</td><td>" +
      c.status +
      "</td><td>" +
      escape_html(c.content) +
      "</td><td>" +
      admin_comment_parent(c) +
      "</td>" +
      "<td>" +
      admin_comment_time(c) +
      "</td>" +
      "</tr>",
    )
  }
  out.write_string("</tbody></table></div><p>")
  let page = rest_positive(query.get("page").unwrap_or("1"), 4096)
  for number in [page - 1, page + 1] {
    if number >= 1 && number <= pages {
      out.write_string(
        "<a href=\"" +
        admin_comment_url(
          query,
          Map([("status", status), ("page", number.to_string())]),
        ) +
        "\">Page \{number}</a> · ",
      )
    }
  }
  out.write_string("</p>")
  admin_page("コメント", out.to_string(), title_en="Comments")
}
