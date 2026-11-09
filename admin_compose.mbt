///|
fn compose_keys() -> Array[String] {
  ["token", "name", "version", "title", "body", "intent", "description", "date"]
}

///|
fn compose_values(
  snapshot : PostSnapshot,
  token : String,
  name : String,
) -> Map[String, String] raise {
  let edit = post_fields(snapshot.content, name)
  let document = parse_document(snapshot.content, name)
  ignore(document)
  {
    "token": token,
    "name": name,
    "version": snapshot.digest,
    "title": edit.title,
    "body": edit.body,
    "description": edit.description,
    "date": edit.date,
  }
}

///|
fn compose_validate(fields : Map[String, String]) -> Unit raise {
  let keys = compose_keys()
  if fields.length() != keys.length() ||
    fields.keys().any(key => !keys.contains(key)) {
    raise InvalidInput("Invalid article editor fields")
  }
  if !["save"].contains(admin_field(fields, "intent")) {
    raise InvalidInput("Invalid article editor action")
  }
}

///|
fn compose_source(
  snapshot : PostSnapshot,
  name : String,
  fields : Map[String, String],
) -> String raise {
  let previous = post_fields(snapshot.content, name)
  ignore(previous)
  let result = source_with_fields(snapshot.content, name, {
    title: admin_field(fields, "title"),
    body: admin_field(fields, "body"),
    description: admin_field(fields, "description"),
    date: admin_field(fields, "date"),
    tags: previous.tags,
  })

  result
}

///|
fn compose_text_field(
  key : String,
  label : String,
  value : String,
  rows : String,
) -> String {
  "<label>" +
  label +
  "<textarea name=\"" +
  key +
  "\" rows=\"" +
  rows +
  "\"" +
  (if key == "body" {
    " class=\"compose-body\""
  } else {
    " class=\"compose-small\""
  }) +
  ">\n" +
  escape_html(value) +
  "</textarea></label>"
}

///|
fn compose_select(
  key : String,
  label : String,
  value : String,
  choices : Array[(String, String)],
) -> String {
  let out = StringBuilder()
  out.write_string("<label>" + label + "<select name=\"" + key + "\">")
  if !choices.any(choice => choice.0 == value) {
    out.write_string(
      "<option selected value=\"" +
      escape_html(value) +
      "\">" +
      escape_html(value) +
      "</option>",
    )
  }
  for (option, text) in choices {
    out.write_string(
      "<option value=\"" +
      escape_html(option) +
      "\"" +
      (if option == value { " selected" } else { "" }) +
      ">" +
      text +
      "</option>",
    )
  }
  out.write_string("</select></label>")
  out.to_string()
}

///|
fn compose_form(
  input : String,
  token : String,
  values : Map[String, String],
) -> String {
  ignore(input)
  let out = StringBuilder()
  out.write_string(
    "<form method=\"post\" action=\"/compose-save\" id=\"compose-form\">",
  )
  out.write_string(admin_hidden("token", token))
  for key in ["name", "version"] {
    out.write_string(admin_hidden(key, values.get(key).unwrap_or("")))
  }
  out.write_string("<div class=\"compose-toolbar\">")
  out.write_string(
    "<button name=\"intent\" value=\"save\">" +
    admin_i18n("変更を保存", "Save changes") +
    "</button> ",
  )
  out.write_string(
    "</div><div class=\"compose-grid\"><section aria-label=\"Article text\">",
  )
  out.write_string(
    compose_text_field(
      "title",
      admin_i18n("タイトル", "Title"),
      values.get("title").unwrap_or(""),
      "2",
    ),
  )
  out.write_string(
    compose_text_field(
      "body",
      admin_i18n("本文（Markdown）", "Body (Markdown)"),
      values.get("body").unwrap_or(""),
      "18",
    ),
  )

  out.write_string(
    "</section><aside aria-label=\"Article settings\"><h2>" +
    admin_i18n("記事設定", "Article settings") +
    "</h2>",
  )
  out.write_string(
    compose_text_field(
      "description",
      admin_i18n("抜粋", "Excerpt"),
      values.get("description").unwrap_or(""),
      "2",
    ),
  )
  out.write_string(
    compose_text_field(
      "date",
      admin_i18n("記事の日付", "Article date"),
      values.get("date").unwrap_or(""),
      "2",
    ),
  )
  out.write_string(
    "<p>" +
    admin_i18n(
      "本文と設定は一緒に保存します。保存だけではデプロイしません。",
      "Text and settings save together. Saving does not deploy the site.",
    ) +
    "</p></aside></div></form>",
  )
  out.to_string()
}

///|
fn compose_page(
  input : String,
  name : String,
  token : String,
  submitted : Map[String, String],
  notice : String,
  extra : String,
) -> String raise {
  let snapshot = read_post(input, name)
  let values = if submitted.is_empty() {
    compose_values(snapshot, token, name)
  } else {
    submitted
  }
  let document = parse_document(snapshot.content, name)
  admin_page(
    "投稿を編集",
    "<style>.compose-grid{display:grid;grid-template-columns:minmax(0,1fr) 17rem;gap:2rem}.compose-grid label{margin:.7rem 0}.compose-grid textarea.compose-small{min-height:3.5rem}.compose-grid textarea.compose-body{min-height:27rem}.compose-toolbar{display:flex;flex-wrap:wrap;gap:1rem;border-bottom:1px solid #455169;padding:.5rem 0}.compose-state{font-size:.875rem}.compose-grid aside p{font-size:.875rem}.compose-grid aside h2{font-size:1.1rem}.compose-tools{border-top:1px solid #455169;padding:.5rem 0}@media(max-width:50rem){.compose-grid{display:block}.compose-grid textarea.compose-body{min-height:20rem}.compose-toolbar{gap:.4rem 1rem}.compose-grid aside{border-top:1px solid #455169}}</style><p><a href=\"/\">" +
    admin_i18n("投稿一覧へ", "All posts") +
    "</a> · <a href=\"/history?name=" +
    url_component(name) +
    "\">" +
    admin_i18n("履歴", "History") +
    "</a> · <a href=\"/edit?name=" +
    url_component(name) +
    "\">" +
    admin_i18n("詳細編集", "Advanced editor") +
    "</a></p><p class=\"compose-state\">" +
    admin_i18n("保存済みの状態：", "Saved state: ") +
    (if document.draft {
      admin_i18n("下書き", "Draft")
    } else {
      admin_i18n(
        "公開対象（デプロイは別途）", "Ready for build (deployment is separate)",
      )
    }) +
    "</p>" +
    notice +
    extra +
    compose_form(input, token, values),
    title_en="Edit post",
  )
}

///|
fn compose_action(
  input : String,
  token : String,
  fields : Map[String, String],
) -> (Int, String) {
  try {
    compose_validate(fields)
    let name = admin_field(fields, "name")
    let snapshot = read_post(input, name)
    require_post_version(snapshot, admin_field(fields, "version"))
    let source = compose_source(snapshot, name, fields)
    let intent = admin_field(fields, "intent")
    ignore(intent)

    let _ = save_post(input, name, snapshot.digest, source)
    let notice = "<p role=\"status\">" +
      admin_i18n("保存しました。", "Post saved.") +
      "</p>"
    let extra = ""

    (200, compose_page(input, name, token, Map([]), notice, extra))
  } catch {
    error => {
      let notice = "<p role=\"alert\">" +
        escape_html(error.to_string()) +
        "</p>"
      (
        400,
        admin_page(
          "保存できませんでした",
          notice + compose_recovery_copy(fields),
          title_en="Could not save post",
        ),
      )
    }
  }
}

///|
fn compose_recovery_copy(fields : Map[String, String]) -> String {
  let out = StringBuilder()
  out.write_string(
    "<p>" +
    admin_i18n(
      "保存できませんでした。入力を下に残しています。文章を保管してから現在の記事を開き直してください。",
      "Not saved. Your submitted values are retained below. Copy your work before reopening the current article.",
    ) +
    "</p>",
  )
  for key in compose_keys() {
    if key != "token" && key != "intent" {
      if fields.get(key) is Some(value) {
        out.write_string(
          "<label>" +
          escape_html(key) +
          "<textarea readonly>\n" +
          escape_html(value) +
          "</textarea></label>",
        )
      }
    }
  }
  out.write_string(
    "<p><a href=\"/compose?name=" +
    url_component(fields.get("name").unwrap_or("")) +
    "\">" +
    admin_i18n("現在の記事を開く", "Open current article") +
    "</a></p>",
  )
  out.to_string()
}
