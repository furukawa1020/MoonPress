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
  let articles = admin_comment_posts(input)
  (
    200,
    admin_page(
      "コメントの確認",
      "<p>ID: \{c.id} · " +
      admin_i18n("記事", "Post") +
      ": \{c.post} · " +
      admin_i18n("状態", "Status") +
      ": " +
      admin_comment_status(c.status) +
      "</p><p>" +
      escape_html(c.author_name) +
      "</p><pre>" +
      escape_html(c.content) +
      "</pre>" +
      "<p>" +
      admin_comment_post(c.post, articles) +
      "</p>" +
      "<p>" +
      admin_comment_time(c) +
      "</p>" +
      "<p>" +
      admin_i18n("親コメント", "Parent") +
      ": " +
      admin_comment_parent(c) +
      " · <a href=\"/comments?status=any&amp;parent=\{c.id}\">Replies</a></p>" +
      "<p>" +
      admin_comment_root(c, state.rows) +
      "</p>" +
      "<p>" +
      admin_comment_replies(c, state.rows) +
      "</p>" +
      admin_comment_editor(row, token) +
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
  let buttons = if row.comment.status == "trash" {
    "<button name=\"status\" value=\"hold\"><!--mp:ja-->保留に戻す<!--mp:en-->Restore to hold<!--mp:end--></button>"
  } else {
    "<button name=\"status\" value=\"approved\"><!--mp:ja-->承認<!--mp:en-->Approve<!--mp:end--></button> <button name=\"status\" value=\"hold\"><!--mp:ja-->保留<!--mp:en-->Hold<!--mp:end--></button> <button name=\"status\" value=\"spam\"><!--mp:ja-->スパム<!--mp:en-->Spam<!--mp:end--></button> <button name=\"status\" value=\"trash\"><!--mp:ja-->ゴミ箱へ<!--mp:en-->Trash<!--mp:end--></button>"
  }
  "<form method=\"post\" action=\"/comment-status\">" +
  admin_hidden("token", token) +
  admin_hidden("id", row.comment.id.to_string()) +
  admin_hidden("revision", row.revision) +
  buttons +
  "</form>"
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
  if !["approved", "hold", "spam", "trash"].contains(status) {
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

///|
fn admin_comment_parent(c : NativeComment) -> String {
  match c.parent {
    Some(id) => "<a href=\"/comment?id=\{id}\">\{id}</a>"
    None => "0"
  }
}
