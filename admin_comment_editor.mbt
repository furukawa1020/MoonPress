///|
fn admin_comment_editor(row : CommentRow, token : String) -> String {
  if row.comment.status == "trash" {
    return ""
  }
  let out = StringBuilder()
  out.write_string(
    "<h2><!--mp:ja-->コメントを編集<!--mp:en-->Edit comment<!--mp:end--></h2><form method=\"post\" action=\"/comment-edit\">",
  )
  out.write_string(admin_hidden("token", token))
  out.write_string(admin_hidden("id", row.comment.id.to_string()))
  out.write_string(admin_hidden("revision", row.revision))
  out.write_string(
    "<label><!--mp:ja-->公開表示名<!--mp:en-->Public author name<!--mp:end--><input name=\"author_name\" required maxlength=\"80\" value=\"",
  )
  out.write_string(escape_html(row.comment.author_name))
  out.write_string(
    "\"></label><p><!--mp:ja-->表示名はUTF-8で80バイトまでです。<!--mp:en-->Public names are limited to 80 UTF-8 bytes.<!--mp:end--></p>",
  )
  out.write_string(
    "<label><!--mp:ja-->本文<!--mp:en-->Comment text<!--mp:end--><textarea name=\"content\" required maxlength=\"8192\">\n",
  )
  out.write_string(escape_html(row.comment.content))
  out.write_string(
    "</textarea></label><p><!--mp:ja-->本文はUTF-8で8192バイトまで保存できます。<!--mp:en-->Comment text is limited to 8192 UTF-8 bytes.<!--mp:end--></p>",
  )
  out.write_string(
    "<label><!--mp:ja-->承認状態<!--mp:en-->Moderation status<!--mp:end--><select name=\"status\">",
  )
  for status in ["hold", "approved", "spam"] {
    out.write_string(
      "<option value=\"" +
      status +
      "\"" +
      (if row.comment.status == status { " selected" } else { "" }) +
      ">" +
      status +
      "</option>",
    )
  }
  out.write_string("</select></label>")
  out.write_string(
    "<button><!--mp:ja-->コメントを保存<!--mp:en-->Save comment<!--mp:end--></button></form>",
  )
  out.to_string()
}

///|
fn operator_comment_edit(
  input : String,
  id : Int,
  revision : String,
  updates : Map[String, Json],
) -> RestResponse raise {
  let content = open_authoring_subdirectory(input, "content")
  defer directory_close(content.fd)
  content.lock()
  native_comment_edit(input, content, id, Some("\"" + revision + "\""), updates)
}

///|
fn admin_comment_edit_action(
  input : String,
  token : String,
  fields : Map[String, String],
) -> (Int, String) raise {
  let allowed = ["token", "id", "revision", "content", "author_name", "status"]
  if fields.length() != allowed.length() ||
    fields.keys().any(key => !allowed.contains(key)) {
    raise InvalidInput("Invalid comment edit fields")
  }
  let id = rest_positive(admin_field(fields, "id"), 2147483647)
  let updates : Map[String, Json] = Map([
    ("content", admin_field(fields, "content").to_json()),
    ("author_name", admin_field(fields, "author_name").to_json()),
    ("status", admin_field(fields, "status").to_json()),
  ])
  let result = operator_comment_edit(
    input,
    id,
    admin_field(fields, "revision"),
    updates,
  )
  if result.code != 200 {
    return (
      result.code,
      admin_page(
        "コメントを保存できませんでした",
        "<p><!--mp:ja-->入力した内容を下に残しています。現在のコメントを開いて内容を確認し、必要な文章をコピーしてから保存し直してください。<!--mp:en-->Your submitted text is retained below. Open the current comment, compare it and copy the text you want to keep before saving again.<!--mp:end--></p><label><!--mp:ja-->入力した表示名<!--mp:en-->Submitted author name<!--mp:end--><input readonly value=\"" +
        escape_html(fields.get("author_name").unwrap_or("")) +
        "\"></label><label><!--mp:ja-->入力した本文<!--mp:en-->Submitted comment text<!--mp:end--><textarea readonly>\n" +
        escape_html(admin_field(fields, "content")) +
        "</textarea></label><p><a href=\"/comment?id=\{id}\"><!--mp:ja-->現在のコメントを確認する<!--mp:en-->Inspect current comment<!--mp:end--></a></p>",
        title_en="Comment not saved",
      ),
    )
  }
  let (code, page) = admin_comment_item(
    input,
    Map([("id", id.to_string())]),
    token,
  )
  (
    code,
    page.replace_all(
      old="<h1>",
      new="<p role=\"status\"><!--mp:ja-->コメントを保存しました。<!--mp:en-->Comment saved.<!--mp:end--></p><h1>",
    ),
  )
}
