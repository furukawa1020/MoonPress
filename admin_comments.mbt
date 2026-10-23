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
    "\"></label><button><!--mp:ja-->探す<!--mp:en-->Search<!--mp:end--></button></form><p>\{rows.length()} comments</p><div class=\"table-scroll\"><table><thead><tr><th>ID</th><th>Post</th><th>Author</th><th>Status</th><th>Text</th></tr></thead><tbody>",
  )
  for i = start; i < rows.length() && i < start + size; i = i + 1 {
    let c = rows[i].comment
    out.write_string(
      "<tr><td><a href=\"/comment?id=\{c.id}\">\{c.id}</a></td><td>\{c.post}</td><td>" +
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

///|
fn admin_comment_item(
  input : String,
  query : Map[String, String],
  token : String,
) -> (Int, String) raise {
  if query.length() != 1 {
    raise InvalidInput("Expected one comment ID")
  }
  let id = rest_positive(admin_field(query, "id"), 2147483647)
  let state = comment_snapshot(input)
  if id > state.rows.length() {
    return (
      404,
      admin_page(
        "Comment missing", "<p>This comment does not exist.</p><p><a href=\"/comments\">Comments</a></p>",
      ),
    )
  }
  let row = state.rows[id - 1]
  let c = row.comment
  (
    200,
    admin_page(
      "コメントの確認",
      "<p>ID: \{c.id} · Post: \{c.post} · Status: " +
      c.status +
      "</p><p>" +
      escape_html(c.author_name) +
      "</p><pre>" +
      escape_html(c.content) +
      "</pre>" +
      admin_comment_actions(row, token) +
      "<p>Revision: <code>" +
      row.revision +
      "</code></p><p><a href=\"/comments?status=" +
      c.status +
      "\"><!--mp:ja-->一覧へ戻る<!--mp:en-->Return to comments<!--mp:end--></a></p>",
      title_en="Inspect comment",
    ),
  )
}

///|
fn admin_comment_actions(row : CommentRow, token : String) -> String {
  if row.comment.status == "trash" {
    return ""
  }
  "<form method=\"post\" action=\"/comment-status\">" +
  admin_hidden("token", token) +
  admin_hidden("id", row.comment.id.to_string()) +
  admin_hidden("revision", row.revision) +
  "<button name=\"status\" value=\"approved\"><!--mp:ja-->承認<!--mp:en-->Approve<!--mp:end--></button> <button name=\"status\" value=\"hold\"><!--mp:ja-->保留<!--mp:en-->Hold<!--mp:end--></button> <button name=\"status\" value=\"spam\"><!--mp:ja-->スパム<!--mp:en-->Spam<!--mp:end--></button></form>"
}

///|
fn operator_comment_change(
  input : String,
  id : Int,
  revision : String,
  status : String,
) -> RestResponse raise {
  let content = open_authoring_subdirectory(input, "content")
  defer directory_close(content.fd)
  content.lock()
  native_comment_change(
    input,
    content,
    id,
    Some("\"" + revision + "\""),
    status,
  )
}

///|
fn admin_comment_action(
  input : String,
  token : String,
  fields : Map[String, String],
) -> (Int, String) raise {
  if fields.length() != 4 {
    raise InvalidInput("Invalid comment action fields")
  }
  let id = rest_positive(admin_field(fields, "id"), 2147483647)
  let status = admin_field(fields, "status")
  if !["approved", "hold", "spam"].contains(status) {
    raise InvalidInput("Invalid comment action")
  }
  let result = operator_comment_change(
    input,
    id,
    admin_field(fields, "revision"),
    status,
  )
  if result.code != 200 {
    return (
      result.code,
      admin_page(
        "Comment unchanged",
        "<p>The comment changed, is unavailable, or cannot enter this state. Reload and review before retrying.</p><p><a href=\"/comment?id=\{id}\">Inspect current comment</a></p>",
      ),
    )
  }
  admin_comment_item(input, Map([("id", id.to_string())]), token)
}
