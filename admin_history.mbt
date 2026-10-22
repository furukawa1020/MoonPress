///|
fn admin_history(
  input : String,
  token : String,
  fields : Map[String, String],
) -> String raise {
  if fields.length() != 1 {
    raise InvalidInput("History requires one article name")
  }
  let name = admin_field(fields, "name")
  let current = read_post(input, name)
  let revisions = list_post_revisions(input, name)
  let hidden = admin_hidden("token", token) + admin_hidden("name", name)
  let out = StringBuilder()
  out.write_string(
    "<p><a href=\"/edit?name=" +
    url_component(name) +
    "\">" +
    admin_i18n("記事へ戻る", "Back to article") +
    "</a></p><p>" +
    escape_html(current.source) +
    " · SHA-256: <code>" +
    current.digest +
    "</code></p>",
  )
  if path_kind(input + "/.moonpress-history") == 0 {
    out.write_string(
      "<p>" +
      admin_i18n(
        "履歴を有効にすると、以後の保存前の内容を保管します。過去に失われた編集は復元できません。",
        "Enable history to retain content before future saves. Previously lost edits cannot be recovered.",
      ) +
      "</p><form method=\"post\" action=\"/history-enable\">" +
      hidden +
      "<button>" +
      admin_i18n("履歴を有効にする", "Enable article history") +
      "</button></form>",
    )
  } else {
    out.write_string(
      "<p>" +
      admin_i18n(
        "履歴は有効です。同じ内容は1つの版として保管します。復元時も現在の版を残します。",
        "History is enabled. Identical content is one distinct version. Restoring also preserves the current version.",
      ) +
      "</p><form method=\"post\" action=\"/checkpoint\">" +
      hidden +
      admin_hidden("version", current.digest) +
      "<button>" +
      admin_i18n("今の内容を履歴へ残す", "Checkpoint current content") +
      "</button></form>",
    )
  }
  out.write_string(
    admin_table_start("Article revisions") +
    "<thead><tr><th>ID</th><th>UTC epoch</th><th>Bytes</th><th>" +
    admin_i18n("操作", "Action") +
    "</th></tr></thead><tbody>",
  )
  for revision in revisions {
    out.write_string(
      "<tr><td><code>" +
      revision.digest +
      "</code></td><td>\{revision.created}</td><td>\{revision.bytes}</td><td><a href=\"/revision?name=" +
      url_component(name) +
      "&amp;id=" +
      revision.id +
      "\">" +
      admin_i18n("確認・復元", "Inspect and restore") +
      "</a></td></tr>",
    )
  }
  out.write_string(
    "</tbody></table></div><p>" +
    admin_i18n(
      "履歴はPC内の非公開領域に保存します。生成物のビルドや公開は別の操作です。",
      "History stays in a private local vault. Building output and deployment remain separate operations.",
    ) +
    "</p>",
  )
  admin_page("Article history", out.to_string())
}

///|
fn admin_revision(
  input : String,
  token : String,
  fields : Map[String, String],
) -> String raise {
  if fields.length() != 2 {
    raise InvalidInput("Revision requires exactly name and id")
  }
  let name = admin_field(fields, "name")
  let revision = read_post_revision(input, admin_field(fields, "id"))
  if revision.revision.name != name {
    raise InvalidInput("Revision belongs to another article")
  }
  let current = read_post(input, name)
  admin_page(
    "Inspect article revision",
    "<p><a href=\"/revision-diff?name=" +
    url_component(name) +
    "&amp;id=" +
    revision.revision.id +
    "\">" +
    admin_i18n("現在の内容と比較する", "Compare with current content") +
    "</a></p>" +
    "<p><a href=\"/history?name=" +
    url_component(name) +
    "\">" +
    admin_i18n("履歴一覧へ", "Back to history") +
    "</a></p><p>" +
    escape_html(name) +
    " · saved SHA-256: <code>" +
    current.digest +
    "</code> · revision SHA-256: <code>" +
    revision.revision.digest +
    "</code></p><label>" +
    admin_i18n("この版の内容", "Revision source") +
    "<textarea readonly>\n" +
    escape_html(revision.content) +
    "</textarea></label><p>" +
    admin_i18n(
      "復元すると記事本文とメタデータをこの版へ戻します。確認後に記事が変わっていたら停止します。現在の版も履歴に残します。自動公開はしません。",
      "Restoring replaces the article source and metadata with this version. A changed current article stops restoration. The current version is retained too. Nothing is deployed.",
    ) +
    "</p><form method=\"post\" action=\"/restore-revision\">" +
    admin_hidden("token", token) +
    admin_hidden("name", name) +
    admin_hidden("version", current.digest) +
    admin_hidden("id", revision.revision.id) +
    "<button>" +
    admin_i18n("確認した版に戻す", "Restore this reviewed version") +
    "</button></form>",
  )
}

///|
fn admin_history_action(
  input : String,
  token : String,
  target : String,
  fields : Map[String, String],
) -> String raise {
  let name = admin_field(fields, "name")
  if target == "/history-enable" {
    if fields.length() != 2 {
      raise InvalidInput("Invalid history-enable fields")
    }
    read_post(input, name) |> ignore
    enable_post_history(input) |> ignore
  } else if target == "/checkpoint" {
    if fields.length() != 3 {
      raise InvalidInput("Invalid checkpoint fields")
    }
    checkpoint_post(input, name, admin_field(fields, "version")) |> ignore
  } else {
    if fields.length() != 4 {
      raise InvalidInput("Invalid revision restore fields")
    }
    restore_post_revision(
      input,
      name,
      admin_field(fields, "version"),
      admin_field(fields, "id"),
    )
    |> ignore
  }
  admin_history(input, token, Map([("name", name)]))
}
