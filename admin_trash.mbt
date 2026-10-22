///|
fn admin_trash(input : String) -> String raise {
  let items = list_trashed_posts(input)
  let out = StringBuilder()
  out.write_string(
    "<p>" +
    admin_i18n(
      "ゴミ箱は非公開のローカル保管場所です。復元時は元のファイル名が空いている必要があります。記事の移動や復元だけでは生成物や公開先は変わりません。",
      "Trash is a private local vault. Restore requires the original filename to be free. Moving or restoring an article does not rebuild or deploy output.",
    ) +
    "</p>" +
    admin_table_start("Article trash") +
    "<thead><tr><th>Source</th><th>UTC epoch</th><th>Bytes</th><th>Action</th></tr></thead><tbody>",
  )
  for item in items {
    out.write_string(
      "<tr><td>" +
      escape_html(item.name) +
      "</td><td>\{item.created}</td><td>\{item.bytes}</td><td><a href=\"/trash-item?id=" +
      item.id +
      "\">" +
      admin_i18n("確認・復元", "Inspect and restore") +
      "</a></td></tr>",
    )
  }
  out.write_string(
    "</tbody></table></div><p><a href=\"/\">" +
    admin_i18n("記事一覧へ", "Back to articles") +
    "</a></p>",
  )
  admin_page("Article trash", out.to_string())
}

///|
fn admin_trash_item(
  input : String,
  token : String,
  fields : Map[String, String],
) -> String raise {
  if fields.length() != 1 {
    raise InvalidInput("Trash detail requires exactly one id")
  }
  let item = read_trashed_post(input, admin_field(fields, "id"))
  let hidden = admin_hidden("token", token) +
    admin_hidden("id", item.revision.id) +
    admin_hidden("version", item.revision.record_digest)
  admin_page(
    "Inspect trashed article",
    "<p><a href=\"/trash\">" +
    admin_i18n("ゴミ箱へ戻る", "Back to trash") +
    "</a></p><p>" +
    escape_html(item.revision.name) +
    " · record SHA-256: <code>" +
    item.revision.record_digest +
    "</code></p><label>" +
    admin_i18n("保管した内容", "Retained article source") +
    "<textarea readonly>\n" +
    escape_html(item.content) +
    "</textarea></label><p>" +
    admin_i18n(
      "元のファイル名が存在する場合は上書きせず停止します。復元後もサイトの検証とビルドは別に行ってください。",
      "An occupied original filename stops restoration without overwriting it. Validate and build separately after restoring.",
    ) +
    "</p><form method=\"post\" action=\"/trash-restore\">" +
    hidden +
    "<button>" +
    admin_i18n("元の場所へ復元する", "Restore to original filename") +
    "</button></form>",
  )
}

///|
fn admin_trash_review(
  input : String,
  token : String,
  fields : Map[String, String],
) -> String raise {
  if fields.length() != 1 {
    raise InvalidInput("Trash review requires exactly one article name")
  }
  let name = admin_field(fields, "name")
  let snapshot = read_post(input, name)
  admin_page(
    "Review move to trash",
    "<p>" +
    escape_html(snapshot.source) +
    "</p><p>" +
    admin_i18n(
      "保存済みの記事を非公開のゴミ箱へ保管し、content/から取り除きます。公開用の生成物はそのまま残ります。リンク先にしている記事があると、次のビルドで修正が必要になる場合があります。未保存の文章は含まれません。",
      "Move this saved article into private trash and remove it from content/. Existing generated output remains. Articles linking here may need repair before the next build. Unsaved text is excluded.",
    ) +
    "</p><p><a href=\"/references?name=" +
    url_component(name) +
    "\">" +
    admin_i18n("参照を確認する", "Inspect references") +
    "</a></p><form method=\"post\" action=\"/trash-post\">" +
    admin_hidden("token", token) +
    admin_hidden("name", name) +
    admin_hidden("version", snapshot.digest) +
    "<button>" +
    admin_i18n(
      "確認した記事をゴミ箱へ移す", "Move reviewed article to trash",
    ) +
    "</button></form>",
  )
}

///|
fn admin_trash_action(
  input : String,
  target : String,
  fields : Map[String, String],
) -> String raise {
  if fields.length() != 3 {
    raise InvalidInput("Invalid trash operation fields")
  }
  if target == "/trash-post" {
    trash_post(
      input,
      admin_field(fields, "name"),
      admin_field(fields, "version"),
    )
    |> ignore
  } else {
    restore_trashed_post(
      input,
      admin_field(fields, "id"),
      admin_field(fields, "version"),
    )
    |> ignore
  }
  admin_trash(input)
}
