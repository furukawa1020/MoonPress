///|
fn admin_comments(input : String, query : Map[String, String]) -> String raise {
  for key, _ in query {
    if !["status", "page", "search"].contains(key) {
      raise InvalidInput("Invalid comment query")
    }
  }
  let status = query.get("status").unwrap_or("hold")
  if !["any", "hold", "approved", "spam", "trash"].contains(status) {
    raise InvalidInput("Invalid comment status")
  }
  let search = native_query_text(query.get("search").unwrap_or(""))
  let state = comment_snapshot(input)
  let rows = state.rows.filter(row => {
    (status == "any" || row.comment.status == status) &&
    (row.comment.content + "\n" + row.comment.author_name)
    .to_lower()
    .contains(search)
  })
  let (start, size, pages) = match rest_page_bounds(rows.length(), query) {
    Some(value) => value
    None => raise InvalidInput("Comment page out of range")
  }
  let out = StringBuilder()
  out.write_string(
    "<p><!--mp:ja-->ローカル管理者用のコメント一覧です。未承認の本文は公開しません。<!--mp:en-->Local operator comment inventory. Pending text remains unpublished.<!--mp:end--></p><p>",
  )
  for filter in ["hold", "approved", "spam", "trash", "any"] {
    let count = state.rows
      .filter(row => filter == "any" || row.comment.status == filter)
      .length()
    out.write_string(
      "<a href=\"/comments?status=" +
      filter +
      "\">" +
      filter +
      " (\{count})</a> · ",
    )
  }
  out.write_string(
    "</p><form method=\"get\" action=\"/comments\">" +
    admin_hidden("status", status) +
    "<label><!--mp:ja-->コメントを探す<!--mp:en-->Search comments<!--mp:end--><input name=\"search\" maxlength=\"256\" value=\"" +
    escape_html(query.get("search").unwrap_or("")) +
    "\"></label><button><!--mp:ja-->探す<!--mp:en-->Search<!--mp:end--></button></form><p>\{rows.length()} comments</p>" + admin_table_start("Comments") + "<thead><tr><th>ID</th><th>Post</th><th>Author</th><th>Status</th><th>Text</th></tr></thead><tbody>",
  )
  for i = start; i < rows.length() && i < start + size; i = i + 1 {
    let c = rows[i].comment
    out.write_string(
      "<tr><td>\{c.id}</td><td>\{c.post}</td><td>" +
      escape_html(c.author_name) +
      "</td><td>" +
      c.status +
      "</td><td>" +
      escape_html(c.content) +
      "</td></tr>",
    )
  }
  out.write_string("</tbody></table></div><p>")
  let page = rest_positive(query.get("page").unwrap_or("1"), 4096)
  for number in [page - 1, page + 1] {
    if number >= 1 && number <= pages {
      out.write_string(
        "<a href=\"/comments?status=" +
        status +
        "&amp;page=\{number}&amp;search=" +
        url_component(query.get("search").unwrap_or("")) +
        "\">Page \{number}</a> · ",
      )
    }
  }
  out.write_string("</p>")
  admin_page("コメント", out.to_string(), title_en="Comments")
}
