///|
fn compose_keys() -> Array[String] {
  [
    "token", "name", "version", "title", "body", "intent", "description", "date",
    "tags", "categories", "slug", "listed", "layout", "kind", "publish_at", "block_kind",
    "block_text", "media", "alt",
  ]
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
    "tags": edit.tags,
    "categories": document.categories.join("\n"),
    "slug": document.slug.unwrap_or(""),
    "listed": if document.listed {
      "yes"
    } else {
      "no"
    },
    "layout": document.layout.unwrap_or(""),
    "kind": document.kind,
    "publish_at": document.publish_at.unwrap_or(""),
    "block_kind": "paragraph",
    "block_text": "",
    "media": "",
    "alt": "",
  }
}

///|
fn compose_validate(fields : Map[String, String]) -> Unit raise {
  let keys = compose_keys()
  if fields.length() != keys.length() ||
    fields.keys().any(key => !keys.contains(key)) {
    raise InvalidInput("Invalid article editor fields")
  }
  if !["save", "draft", "ready", "preview", "block", "media", "preview_saved"].contains(
      admin_field(fields, "intent"),
    ) {
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
  let mut result = source_with_fields(snapshot.content, name, {
    title: admin_field(fields, "title"),
    body: admin_field(fields, "body"),
    description: admin_field(fields, "description"),
    date: admin_field(fields, "date"),
    tags: admin_field(fields, "tags"),
  })
  let document = parse_document(result, name)
  ignore(document)
  let listed = admin_field(fields, "listed")
  if !["yes", "no"].contains(listed) {
    raise InvalidInput("Invalid listing")
  }
  result = source_with_settings(result, name, {
    slug: admin_field(fields, "slug"),
    listed: listed == "yes",
    layout: admin_field(fields, "layout"),
  })
  let document = parse_document(result, name)
  let (json, body) = document_parts(result, name)
  let metadata = match json {
    Object(fields) => fields
    _ => raise InvalidInput("Invalid article metadata")
  }
  let mut changed = false
  let categories = if post_form_text(admin_field(fields, "categories")) ==
    post_form_text(document.categories.join("\n")) {
    document.categories
  } else {
    normalized_categories(admin_field(fields, "categories"))
  }
  if categories != document.categories {
    metadata["categories"] = categories.to_json()
    changed = true
  }
  let kind = admin_field(fields, "kind")
  if !["post", "page"].contains(kind) {
    raise InvalidInput("Invalid article type")
  }
  if kind != document.kind {
    metadata["kind"] = kind.to_json()
    changed = true
  }
  let schedule = admin_field(fields, "publish_at")
  if !schedule.is_empty() {
    publication_timestamp(schedule) |> ignore
  }
  if schedule != document.publish_at.unwrap_or("") {
    if schedule.is_empty() {
      metadata.remove("publish_at")
    } else {
      metadata["publish_at"] = schedule.to_json()
    }
    changed = true
  }
  let intent = admin_field(fields, "intent")
  let draft = if intent == "draft" {
    true
  } else if intent == "ready" {
    false
  } else {
    document.draft
  }
  if draft != document.draft {
    metadata["draft"] = draft.to_json()
    changed = true
  }
  if changed {
    result = "---\n" + json.stringify() + "\n---\n" + body
  }
  parse_document(result, name) |> ignore
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
    "<button name=\"intent\" value=\"draft\">" +
    admin_i18n("下書き保存", "Save as draft") +
    "</button> ",
  )
  out.write_string(
    "<button name=\"intent\" value=\"preview\">" +
    admin_i18n("未保存の本文を確認", "Preview unsaved text") +
    "</button> ",
  )
  out.write_string(
    "<button name=\"intent\" value=\"preview_saved\">" +
    admin_i18n("保存してプレビュー", "Save and build preview") +
    "</button> ",
  )
  out.write_string(
    "<button name=\"intent\" value=\"ready\">" +
    admin_i18n("公開の確認へ", "Save and review publication") +
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
    "<details class=\"compose-tools\"><summary>" +
    admin_i18n("文章を追加", "Add content") +
    "</summary>",
  )
  out.write_string(
    compose_select(
      "block_kind",
      admin_i18n("種類", "Block type"),
      values.get("block_kind").unwrap_or("paragraph"),
      [
        ("paragraph", admin_i18n("段落", "Paragraph")),
        ("heading", admin_i18n("見出し", "Heading")),
        ("list", admin_i18n("箇条書き", "List")),
        ("quote", admin_i18n("引用", "Quote")),
        ("code", admin_i18n("コード", "Code")),
      ],
    ),
  )
  out.write_string(
    compose_text_field(
      "block_text",
      admin_i18n("追加する文章", "Content to append"),
      values.get("block_text").unwrap_or(""),
      "3",
    ),
  )
  out.write_string(
    "<button name=\"intent\" value=\"block\">" +
    admin_i18n("本文へ追加（未保存）", "Append to editor (unsaved)") +
    "</button></details>",
  )
  out.write_string(compose_media(input, values))
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
    compose_text_field(
      "tags",
      admin_i18n("タグ（1行にひとつ）", "Tags (one per line)"),
      values.get("tags").unwrap_or(""),
      "2",
    ),
  )
  out.write_string(
    compose_text_field(
      "categories",
      admin_i18n(
        "カテゴリ（1行にひとつ）", "Categories (one per line)",
      ),
      values.get("categories").unwrap_or(""),
      "2",
    ),
  )
  out.write_string(
    compose_text_field(
      "slug",
      admin_i18n(
        "URLの末尾（空欄ならファイル名）", "URL stem (blank: filename)",
      ),
      values.get("slug").unwrap_or(""),
      "2",
    ),
  )
  out.write_string(
    compose_select(
      "listed",
      admin_i18n("一覧への掲載", "Listing"),
      values.get("listed").unwrap_or(""),
      [
        ("yes", admin_i18n("一覧に掲載", "Listed")),
        (
          "no",
          admin_i18n(
            "一覧非掲載（URLは公開）", "Unlisted (URL remains public)",
          ),
        ),
      ],
    ),
  )
  out.write_string(
    compose_text_field(
      "layout",
      admin_i18n(
        "テンプレート（空欄なら標準）", "Layout (blank: default)",
      ),
      values.get("layout").unwrap_or(""),
      "2",
    ),
  )
  out.write_string(
    compose_select(
      "kind",
      admin_i18n("種別", "Type"),
      values.get("kind").unwrap_or(""),
      [
        ("post", admin_i18n("投稿", "Post")),
        ("page", admin_i18n("固定ページ", "Page")),
      ],
    ),
  )
  out.write_string(
    compose_text_field(
      "publish_at",
      admin_i18n(
        "公開予約（UTC・空欄で解除）", "Schedule (UTC; blank to remove)",
      ),
      values.get("publish_at").unwrap_or(""),
      "2",
    ),
  )
  out.write_string(
    "<p>" +
    admin_i18n(
      "予約時刻には再ビルドと配信が必要です。自動配信は行いません。",
      "A build and deployment at the scheduled time is required; no automatic scheduler runs here.",
    ) +
    "</p>",
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
    if intent == "preview" {
      return (
        200,
        compose_page(
          input,
          name,
          token,
          fields,
          "",
          admin_body_preview(parse_document(source, name).body),
        ),
      )
    }
    if intent == "block" {
      let values = fields.copy()
      values["body"] = admin_field(fields, "body") +
        "\n\n" +
        compose_block(
          admin_field(fields, "block_kind"),
          admin_field(fields, "block_text"),
        ) +
        "\n"
      values["block_text"] = ""
      return (
        200,
        compose_page(
          input,
          name,
          token,
          values,
          "<p role=\"status\">" +
          admin_i18n(
            "本文へ追加しました。まだ保存していません。", "Added to the editor; not saved yet.",
          ) +
          "</p>",
          "",
        ),
      )
    }
    if intent == "media" {
      let chosen = admin_field(fields, "media")
      let mut selected : String? = None
      for image in public_asset_names(input) {
        if image_asset_name(image) && "public/" + image == chosen {
          selected = Some(image)
        }
      }
      let url = match selected {
        Some(image) => url_component(image)
        _ => raise InvalidInput("Select an existing library image")
      }
      let alt = admin_field(fields, "alt")
      if alt.trim().is_empty() ||
        @utf8.encode(alt).length() > 256 ||
        alt.any(c => c.is_control()) ||
        alt.contains("[") ||
        alt.contains("]") ||
        alt.contains("\\") {
        raise InvalidInput(
          "Image description must contain 1–256 UTF-8 bytes without controls, brackets or backslashes",
        )
      }
      let values = fields.copy()
      values["body"] = admin_field(fields, "body") +
        "\n\n![" +
        alt +
        "](" +
        url +
        ")\n"
      return (
        200,
        compose_page(
          input,
          name,
          token,
          values,
          "<p role=\"status\">" +
          admin_i18n(
            "画像を本文へ追加しました。まだ保存していません。",
            "Image inserted into editor; not saved yet.",
          ) +
          "</p>",
          "",
        ),
      )
    }
    let _ = save_post(input, name, snapshot.digest, source)
    let notice = "<p role=\"status\">" +
      admin_i18n("保存しました。", "Post saved.") +
      "</p>"
    let extra = ""
    let extra = if intent == "ready" {
      admin_production_plan_form(token, japanese=true)
    } else {
      extra
    }
    let extra = if intent == "preview_saved" {
      try {
        compile_site(
          input,
          input.trim_end(chars="/").to_owned() + "/.moonpress-preview",
          include_drafts=true,
        )
        |> ignore
        "<p role=\"status\">" +
        admin_i18n(
          "保存してプレビューを生成しました。上の「生成したプレビューを開く」で確認できます。",
          "Saved and built themed preview. Use Open built preview above.",
        ) +
        "</p>"
      } catch {
        error =>
          "<p role=\"alert\">" +
          admin_i18n(
            "記事は保存しましたが、プレビューを生成できませんでした。",
            "Article saved, but preview generation failed.",
          ) +
          " " +
          escape_html(error.to_string()) +
          "</p>"
      }
    } else {
      extra
    }
    (200, compose_page(input, name, token, Map([]), notice, extra))
  } catch {
    error => {
      let notice = "<p role=\"alert\">" +
        escape_html(error.to_string()) +
        "</p>"
      let name = fields.get("name").unwrap_or("")
      let retained = "<p>" +
        admin_i18n(
          "入力した内容と元の版を残しています。競合時は文章を保管してから現在の記事を開き直してください。",
          "Your inputs and original version are retained. On conflict, copy your text before opening the current article.",
        ) +
        " <a href=\"/compose?name=" +
        url_component(name) +
        "\">" +
        admin_i18n("現在の記事を開く", "Open current article") +
        "</a></p>"
      let page = compose_page(input, name, token, fields, notice + retained, "") catch {
        _ =>
          admin_page(
            "保存できませんでした",
            notice + retained + compose_form(input, token, fields),
            title_en="Could not save post",
          )
      }
      (400, page)
    }
  }
}

///|
fn compose_block(kind : String, raw : String) -> String raise {
  let text = raw.replace_all(old="\r\n", new="\n")
  if text.trim().is_empty() ||
    @utf8.encode(text).length() > 8192 ||
    text.any(c => c.is_control() && c != '\n' && c != '\t') {
    raise InvalidInput(
      "Block text must contain 1–8192 UTF-8 bytes without unsupported controls",
    )
  }
  match kind {
    "paragraph" => text
    "heading" => {
      if text.contains("\n") {
        raise InvalidInput("Heading must be one line")
      }
      "## " + text
    }
    "list" => text.split("\n").map(line => "- " + line.to_owned()).join("\n")
    "quote" => text.split("\n").map(line => "> " + line.to_owned()).join("\n")
    "code" => {
      if text.contains("```") {
        raise InvalidInput("Code cannot contain a closing fence")
      }
      "```\n" + text + "\n```"
    }
    _ => raise InvalidInput("Unsupported content type")
  }
}

///|
fn compose_media(input : String, fields : Map[String, String]) -> String {
  let out = StringBuilder()
  out.write_string(
    "<details class=\"compose-tools\"><summary>" +
    admin_i18n("画像を挿入", "Insert image") +
    "</summary>",
  )
  let choices : Array[(String, String)] = [
    ("", admin_i18n("画像を選択", "Choose image")),
  ]
  try {
    for image in public_asset_names(input) {
      if image_asset_name(image) {
        let source = "public/" + image
        choices.push((source, escape_html(source)))
      }
    }
  } catch {
    _ =>
      out.write_string(
        "<p>" +
        admin_i18n(
          "画像一覧を読めません。メディア画面を確認してください。",
          "Library unavailable; inspect Media.",
        ) +
        "</p>",
      )
  }
  out.write_string(
    compose_select(
      "media",
      admin_i18n("メディアライブラリ", "Media library"),
      fields.get("media").unwrap_or(""),
      choices,
    ),
  )
  out.write_string(
    compose_text_field(
      "alt",
      admin_i18n(
        "画像の説明（代替テキスト）", "Image description (alt text)",
      ),
      fields.get("alt").unwrap_or(""),
      "2",
    ),
  )
  out.write_string(
    "<button name=\"intent\" value=\"media\">" +
    admin_i18n("本文へ挿入（未保存）", "Insert into editor (unsaved)") +
    "</button></details>",
  )
  out.to_string()
}
