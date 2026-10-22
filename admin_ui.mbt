///|
fn admin_page(title : String, body : String, title_en? : String = "") -> String {
  let page_title = if title_en.is_empty() {
    admin_i18n(escape_html(admin_title_ja(title)), escape_html(title))
  } else {
    admin_i18n(escape_html(title), escape_html(title_en))
  }
  "<!doctype html><html lang=\"en\"><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>" +
  page_title +
  " — MoonPress</title><style>@font-face{font-family:MoonPixel;src:url(/assets/font.woff) format('woff');font-display:swap}*{box-sizing:border-box}body{font:17px/1.9 MoonPixel,monospace;max-width:68rem;margin:auto;padding:1rem 2rem 3rem;background:#080f24;color:#eee7d5;overflow-wrap:anywhere}a{color:#b9dddc;text-underline-offset:5px}a:hover,button:hover{color:#f4d39a}h1,h2,h3,strong{font-weight:400}h1,h2{color:#f4d39a}nav{display:flex;flex-wrap:wrap;align-items:center;gap:6px 15px;padding:1rem 0;border-bottom:1px solid #455169;overflow-wrap:normal}nav a{display:inline-block;padding:5px 0}.admin-brand{width:260px;max-width:100%;display:block}.admin-brand img{display:block;width:100%;height:auto}.table-scroll{max-width:100%;overflow-x:auto;margin:1rem 0}table{width:100%;min-width:36rem;border-collapse:collapse}td,th{text-align:left;padding:.7rem;border-bottom:1px solid #455169}form{margin:1.5rem 0;padding:1.5rem 0;background:transparent;border:0;border-top:1px solid #455169;border-radius:0;box-shadow:none}label{display:block;margin:1rem 0}input,textarea,button{font:inherit;max-width:100%}input,textarea{width:100%;padding:.6rem;background:#0d1930;color:#fff7df;border:0;border-bottom:1px solid #7b879c;border-radius:0}textarea{min-height:24rem;overflow-wrap:normal;font-family:monospace}input[type=hidden]{display:none}button{padding:.6rem 0;cursor:pointer;border:0;border-bottom:1px solid #bda576;background:none;color:#f4d39a}button:before{content:'▶ ';} :focus-visible{outline:3px solid #f4d39a;outline-offset:4px}.notice{padding:1rem 0 1rem 16px;background:none;border-left:2px solid #bda576}pre{max-width:100%;overflow-x:auto;white-space:pre-wrap}.room-map ol{display:flex;flex-wrap:wrap;gap:8px 20px;padding:0;list-style:none}.room-map [aria-current=step]{color:#f4d39a;text-decoration:underline double}.room-status{font-size:14px;color:#b2bfd0}.room-dialogue{padding:8px 0;margin:20px 0;background:none;border:0;box-shadow:none}.room-art{display:block;width:100%;height:auto;image-rendering:pixelated;margin:20px 0}.room-actions,.room-doors{display:flex;flex-wrap:wrap;gap:16px;margin:20px 0}.room-actions a,.room-doors a{padding:10px 0;background:none;border:0;box-shadow:none;text-decoration:underline;text-underline-offset:6px}.room-window{height:330px;margin:12px -2rem 30px;background-image:url(/assets/rooms.webp);background-size:160%;background-repeat:no-repeat;image-rendering:pixelated;mask-image:linear-gradient(#000 80%,transparent);border:0}.room-window.entrance{background-position:0% 85%}.room-window.writing{background-position:30% 65%}.room-window.preview{background-position:62% 58%}.room-window.building{background-position:100% 55%}.room-window.departure{background-position:100% 0%}.skip-link{position:absolute;left:-10000px;top:0}.skip-link:focus{left:1rem;top:1rem;background:#080f24;color:white;padding:.5rem;z-index:10}@media(max-width:40rem){body{padding:1rem}.room-window{margin-inline:-1rem;height:240px;background-size:210%}td,th{padding:.45rem}textarea{min-height:16rem}button{white-space:normal}.room-doors{display:block}.room-doors a{display:block;margin:12px 0}}</style><a class=\"skip-link\" href=\"#main\"><!--mp:ja-->本文へ移動<!--mp:en-->Skip to content<!--mp:end--></a><nav aria-label=\"Main navigation\"><a class=\"admin-brand\" href=\"/rooms\"><img src=\"/assets/logo.jpg\" width=\"1774\" height=\"887\" alt=\"MoonPress\"></a> · <a href=\"/workflow\"><!--mp:ja-->はじめに<!--mp:en-->Start here<!--mp:end--></a> · <a href=\"/\"><!--mp:ja-->記事<!--mp:en-->Posts<!--mp:end--></a> · <a href=\"/media\"><!--mp:ja-->画像とファイル<!--mp:en-->Media<!--mp:end--></a> · <a href=\"/reference-outputs\"><!--mp:ja-->出力の参照<!--mp:en-->Output references<!--mp:end--></a> · <a href=\"/site-settings\"><!--mp:ja-->サイト設定<!--mp:en-->Site settings<!--mp:end--></a> · <a href=\"/publish\"><!--mp:ja-->公開の準備<!--mp:en-->Publish<!--mp:end--></a> · <a href=\"/rooms\"><!--mp:ja-->出版の冒険<!--mp:en-->Publishing adventure<!--mp:end--></a> · <a href=\"/authoring-recovery\"><!--mp:ja-->編集データの案内所<!--mp:en-->Source editing recovery<!--mp:end--></a> · <a href=\"/trash\"><!--mp:ja-->ゴミ箱<!--mp:en-->Trash<!--mp:end--></a> · Local administration</nav><main id=\"main\" tabindex=\"-1\"><h1>" +
  page_title +
  "</h1>" +
  body +
  "</main></html>"
}

///|
fn admin_hidden(name : String, value : String) -> String {
  "<input type=\"hidden\" name=\"" +
  name +
  "\" value=\"" +
  escape_html(value) +
  "\">"
}

///|
fn admin_fields_form(hidden : String, edit : PostFields) -> String {
  let out = StringBuilder()
  out.write_string("<form method=\"post\" action=\"/fields\">" + hidden)
  for
    (key, label, value) in [
      (
        "title",
        "<!--mp:ja-->タイトル（空欄なら本文から）<!--mp:en-->Title (blank: infer from body)<!--mp:end-->",
        edit.title,
      ),
      (
        "description",
        "<!--mp:ja-->説明<!--mp:en-->Description<!--mp:end-->",
        edit.description,
      ),
      (
        "date",
        "<!--mp:ja-->日付（YYYY-MM-DD・空欄なら日付なし）<!--mp:en-->Date (YYYY-MM-DD; blank: undated)<!--mp:end-->",
        edit.date,
      ),
    ] {
    out.write_string(
      "<label>" +
      label +
      "<textarea name=\"" +
      key +
      "\" rows=\"2\" style=\"min-height:3rem\">\n" +
      escape_html(value) +
      "</textarea></label>",
    )
  }
  out.write_string(
    "<label><!--mp:ja-->タグ（1行にひとつ）<!--mp:en-->Tags (one per line)<!--mp:end--><textarea name=\"tags\" style=\"min-height:5rem\">\n" +
    escape_html(edit.tags) +
    "</textarea></label><label><!--mp:ja-->Markdown本文<!--mp:en-->Markdown body<!--mp:end--><textarea name=\"body\">\n" +
    escape_html(edit.body) +
    "</textarea></label><button><!--mp:ja-->記事を保存<!--mp:en-->Save article<!--mp:end--></button> <button formaction=\"/preview\"><!--mp:ja-->保存せず本文を確認<!--mp:en-->Preview body without saving<!--mp:end--></button></form>",
  )
  out.to_string()
}

///|
fn admin_submitted_fields(fields : Map[String, String]) -> PostFields raise {
  {
    title: admin_field(fields, "title"),
    description: admin_field(fields, "description"),
    date: admin_field(fields, "date"),
    tags: admin_field(fields, "tags"),
    body: admin_field(fields, "body"),
  }
}

///|
fn admin_edit(input : String, name : String, token : String) -> String raise {
  let snapshot = read_post(input, name)
  let hidden = admin_hidden("token", token) +
    admin_hidden("name", name) +
    admin_hidden("version", snapshot.digest)
  let editor = admin_fields_form(hidden, post_fields(snapshot.content, name)) catch {
    error =>
      "<p class=\"notice\">Structured editor unavailable: " +
      escape_html(error.to_string()) +
      ". Repair the source below.</p>"
  }
  let settings = try {
    let edit = post_settings(snapshot.content, filename=name)
    admin_settings_form(
      hidden,
      edit.slug,
      if edit.listed {
        "yes"
      } else {
        "no"
      },
      edit.layout,
    )
  } catch {
    _ => ""
  }
  let copy_title = try
    parse_document(snapshot.content, name).title + " (copy)"
  catch {
    _ => ""
  }
  admin_page(
    "Edit " + name,
    "<p><a href=\"/rooms/write\"><!--mp:ja-->◀ かきかきる〜む<!--mp:en-->◀ Writing room<!--mp:end--></a> · <a href=\"/rooms/preview\"><!--mp:ja-->▶ 保存した記事をプレビューする<!--mp:en-->▶ Preview saved articles<!--mp:end--></a><!--mp:ja-->。移動する前に、下の編集内容を保存してください。<!--mp:en-->. Save the editor below before navigating away.<!--mp:end--></p>" +
    "<p><a href=\"/workflow\"><!--mp:ja-->執筆から公開までの手順<!--mp:en-->Writing and publishing steps<!--mp:end--></a>. Save your article, preview it, then set it ready for build.</p>" +
    "<p><a href=\"/references?name=" +
    url_component(name) +
    "\">Inspect saved article references</a> before changing its URL or removing a source.</p>" +
    "<p><a href=\"/history?name=" +
    url_component(name) +
    "\">" +
    admin_i18n(
      "履歴を確認・復元する（先に本文を保存してください）",
      "Inspect and restore history (save your edits first)",
    ) +
    "</a></p>" +
    "<p><a href=\"/trash-post?name=" +
    url_component(name) +
    "\">" +
    admin_i18n(
      "ゴミ箱へ移す（保存済みの記事）", "Review moving saved article to trash",
    ) +
    "</a></p>" +
    editor +
    settings +
    admin_kind_form(snapshot.content, name, hidden) +
    admin_schedule_form(snapshot.content, name, hidden) +
    admin_categories_form(snapshot.content, name, hidden) +
    admin_duplicate_form(token, name, snapshot.digest, "", copy_title) +
    "<details><summary><!--mp:ja-->詳細：MarkdownとJSONソースを編集<!--mp:en-->Advanced: edit Markdown and JSON source<!--mp:end--></summary><p>Use one editor at a time. Saving validates metadata; use the CLI to check links and preview the full site.</p><form method=\"post\" action=\"/save\">" +
    hidden +
    "<label><!--mp:ja-->ソース<!--mp:en-->Source<!--mp:end--><textarea name=\"content\" spellcheck=\"false\" aria-label=\"Post source\">\n" +
    escape_html(snapshot.content) +
    "</textarea></label><button><!--mp:ja-->ソースを保存<!--mp:en-->Save source<!--mp:end--></button></form></details><form method=\"post\" action=\"/status\">" +
    hidden +
    "<p>These buttons change the saved source. Save the editor above first.</p><button name=\"state\" value=\"draft\"><!--mp:ja-->下書きに戻す<!--mp:en-->Set draft<!--mp:end--></button> <button name=\"state\" value=\"ready\"><!--mp:ja-->公開対象にする<!--mp:en-->Set ready for build<!--mp:end--></button></form>",
  )
}

///|
fn admin_route(
  input : String,
  request : AdminRequest,
  body : String,
  token : String,
) -> (Int, String) raise {
  if request.verb == "GET" {
    if request.target == "/trash" {
      return (200, admin_trash(input))
    }
    if request.target.has_prefix("/trash-item?") {
      return (
        200,
        admin_trash_item(
          input,
          token,
          admin_form(request.target[12:].to_owned()),
        ),
      )
    }
    if request.target.has_prefix("/trash-post?") {
      return (
        200,
        admin_trash_review(
          input,
          token,
          admin_form(request.target[12:].to_owned()),
        ),
      )
    }
    if request.target.has_prefix("/revision-diff?") {
      return (
        200,
        admin_revision_diff(input, admin_form(request.target[15:].to_owned())),
      )
    }
    if request.target.has_prefix("/history?") {
      return (
        200,
        admin_history(input, token, admin_form(request.target[9:].to_owned())),
      )
    }
    if request.target.has_prefix("/revision?") {
      return (
        200,
        admin_revision(input, token, admin_form(request.target[10:].to_owned())),
      )
    }
    if request.target == "/reference-outputs" {
      return admin_output_references(input, Map([]))
    }
    if request.target.has_prefix("/reference-outputs?") {
      return admin_output_references(
        input,
        admin_form(request.target[19:].to_owned()),
      )
    }
    if request.target == "/site-settings" {
      return (200, admin_site_settings(input, token))
    }
    if request.target == "/authoring-recovery" {
      return (200, admin_authoring_recovery(input))
    }
    if request.target == "/recovery" {
      return admin_recovery(input)
    }
    if request.target == "/publish" {
      return admin_publish(input, token)
    }
    if publishing_room(request.target) is Some(room) {
      return (200, admin_room(input, token, room))
    }
    if request.target == "/workflow" {
      return (200, admin_workflow(input, token))
    }
    if request.target.has_prefix("/media-remove?") {
      let fields = admin_form(request.target[14:].to_owned())
      if fields.length() != 1 {
        raise InvalidInput("Invalid media removal query")
      }
      return (
        200,
        admin_media_removal(input, admin_field(fields, "name"), token),
      )
    }
    if request.target.has_prefix("/media-replace?") {
      let fields = admin_form(request.target[15:].to_owned())
      if fields.length() != 1 {
        raise InvalidInput("Invalid media replacement query")
      }
      return (
        200,
        admin_media_replace(input, admin_field(fields, "name"), token),
      )
    }
    if request.target == "/media" {
      return (200, admin_media(input, token, Map([])))
    }
    if request.target.has_prefix("/media?") {
      return (
        200,
        admin_media(input, token, admin_form(request.target[7:].to_owned())),
      )
    }
    if request.target == "/" {
      return (200, admin_posts(input, token, Map([])))
    }
    if request.target.has_prefix("/?") {
      return (
        200,
        admin_posts(input, token, admin_form(request.target[2:].to_owned())),
      )
    }
    if request.target.has_prefix("/edit?") {
      let fields = admin_form(request.target[6:].to_owned())
      if fields.length() != 1 {
        raise InvalidInput("Invalid edit query")
      }
      return (200, admin_edit(input, admin_field(fields, "name"), token))
    }
    if request.target.has_prefix("/references?") {
      return admin_references(input, admin_form(request.target[12:].to_owned()))
    }
    return (
      404,
      admin_page(
        "Not found", "<p>This administration route does not exist.</p>",
      ),
    )
  }
  let fields = admin_form(body)
  if admin_field(fields, "token") != token {
    raise InvalidInput("Form token rejected; reload the page")
  }
  if ["/trash-post", "/trash-restore", "/trash-purge"].contains(request.target) {
    return (200, admin_trash_action(input, request.target, fields))
  }
  if ["/history-enable", "/checkpoint", "/restore-revision"].contains(
      request.target,
    ) {
    return (200, admin_history_action(input, token, request.target, fields))
  }
  if request.target == "/remove-media" {
    return admin_remove_media(input, fields)
  }
  if request.target == "/site-settings" {
    return admin_site_settings_save(input, token, fields)
  }
  try {
    if request.target == "/prepare-media" {
      if fields.length() != 1 {
        raise InvalidInput("Invalid media setup fields")
      }
      let created = prepare_media(input)
      return (
        200,
        admin_page(
          "Media storage ready",
          (if created {
            "<p>Created media storage.</p>"
          } else {
            "<p>Existing media storage is already ready.</p>"
          }) +
          "<p><a href=\"/media\">Choose a file to upload</a></p>",
        ),
      )
    }
    if request.target == "/import" {
      if fields.length() != 3 {
        raise InvalidInput("Invalid import fields")
      }
      let item = import_media(
        input,
        admin_field(fields, "source"),
        admin_field(fields, "name"),
      )
      return (
        200,
        admin_page(
          "Media imported",
          "<p>Imported " +
          escape_html(item.source) +
          " (\{item.bytes} bytes). No deployment performed.</p><label><!--mp:ja-->本文に貼るMarkdown<!--mp:en-->Markdown snippet<!--mp:end--><textarea readonly rows=\"2\" style=\"min-height:4rem\">\n" +
          escape_html(media_snippet(item)) +
          "</textarea></label><p><a href=\"/media\"><!--mp:ja-->画像とファイルへ戻る<!--mp:en-->Return to media<!--mp:end--></a></p>",
        ),
      )
    }
    if request.target == "/duplicate" {
      if fields.length() != 5 {
        raise InvalidInput("Invalid duplicate fields")
      }
      let slug = admin_field(fields, "slug")
      let report = duplicate_post(
        input,
        admin_field(fields, "name"),
        admin_field(fields, "version"),
        slug,
        admin_field(fields, "title"),
      )
      return (
        200,
        admin_page(
          "Draft duplicated",
          "<p>Created " +
          escape_html(report.source) +
          ". Original source unchanged. No deployment performed.</p><p><a href=\"/edit?name=" +
          url_component(slug + ".md") +
          "\">Edit new draft</a></p>",
        ),
      )
    }
    if request.target == "/plan-production" {
      if fields.length() != 1 {
        raise InvalidInput("Invalid production plan fields")
      }
      return (200, admin_plan_production(input, token))
    }
    if request.target == "/build-production" {
      if fields.length() != 2 {
        raise InvalidInput("Invalid production build fields")
      }
      return (
        200,
        admin_build_production(input, token, admin_field(fields, "review_id")),
      )
    }
    if request.target == "/build-preview" {
      if fields.length() != 1 {
        raise InvalidInput("Invalid preview build fields")
      }
      return (200, admin_build_preview(input, token))
    }
    if request.target == "/check" {
      if fields.length() != 2 {
        raise InvalidInput("Invalid validation fields")
      }
      let mode = admin_field(fields, "mode")
      if mode != "ready" && mode != "drafts" {
        raise InvalidInput("Invalid validation mode")
      }
      return (200, admin_check(input, token, mode == "drafts"))
    }
    if request.target == "/preview" {
      if fields.length() != 8 {
        raise InvalidInput("Invalid preview fields")
      }
      let name = admin_field(fields, "name")
      // Validate the source path, but do not require a fresh version to preview
      // unsaved work. The original version remains mandatory when saving.
      let _ = read_post(input, name)
      let hidden = admin_hidden("token", token) +
        admin_hidden("name", name) +
        admin_hidden("version", admin_field(fields, "version"))
      let edit = admin_submitted_fields(fields)
      return (
        200,
        admin_page(
          "Preview " + name,
          admin_body_preview(edit.body) + admin_fields_form(hidden, edit),
        ),
      )
    }
    let name = match request.target {
      "/new" => {
        if fields.length() != 3 {
          raise InvalidInput("Invalid creation fields")
        }
        let slug = admin_field(fields, "slug")
        let _ = new_post(input, slug, admin_field(fields, "title"))
        slug + ".md"
      }
      "/schedule" => {
        if fields.length() != 4 {
          raise InvalidInput("Invalid schedule fields")
        }
        let name = admin_field(fields, "name")
        save_post_schedule(
          input,
          name,
          admin_field(fields, "version"),
          admin_field(fields, "publish_at"),
        )
        |> ignore
        name
      }
      "/categories" => {
        if fields.length() != 4 {
          raise InvalidInput("Invalid category fields")
        }
        let name = admin_field(fields, "name")
        save_post_categories(
          input,
          name,
          admin_field(fields, "version"),
          admin_field(fields, "categories"),
        )
        |> ignore
        name
      }
      "/kind" => {
        if fields.length() != 4 {
          raise InvalidInput("Invalid kind fields")
        }
        let name = admin_field(fields, "name")
        save_post_kind(
          input,
          name,
          admin_field(fields, "version"),
          admin_field(fields, "kind"),
        )
        |> ignore
        name
      }
      "/save" => {
        if fields.length() != 4 {
          raise InvalidInput("Invalid save fields")
        }
        let name = admin_field(fields, "name")
        let _ = save_post(
          input,
          name,
          admin_field(fields, "version"),
          admin_field(fields, "content"),
        )
        name
      }
      "/settings" => {
        if fields.length() != 6 {
          raise InvalidInput("Invalid article settings fields")
        }
        let name = admin_field(fields, "name")
        let _ = save_post_settings(
          input,
          name,
          admin_field(fields, "version"),
          admin_submitted_settings(fields),
        )
        name
      }
      "/fields" => {
        if fields.length() != 8 {
          raise InvalidInput("Invalid article fields")
        }
        let name = admin_field(fields, "name")
        let _ = save_post_fields(
          input,
          name,
          admin_field(fields, "version"),
          admin_submitted_fields(fields),
        )
        name
      }
      "/status" => {
        if fields.length() != 4 {
          raise InvalidInput("Invalid status fields")
        }
        let state = admin_field(fields, "state")
        if state != "draft" && state != "ready" {
          raise InvalidInput("Invalid post state")
        }
        let name = admin_field(fields, "name")
        let _ = set_post_draft(
          input,
          name,
          admin_field(fields, "version"),
          state == "draft",
        )
        name
      }
      _ => raise InvalidInput("Unknown form action")
    }
    (
      200,
      admin_page(
        "Saved",
        "<p>Source saved. No deployment performed.</p><p><a href=\"/edit?name=" +
        url_component(name) +
        "\">Continue editing</a> · <a href=\"/rooms/preview\"><!--mp:ja-->▶ ぷれびゅ〜る〜むへ<!--mp:en-->▶ Enter the preview room<!--mp:end--></a> · <a href=\"/rooms/write\"><!--mp:ja-->かきかきる〜むへ<!--mp:en-->Back to the writing room<!--mp:end--></a> · <a href=\"/workflow\">Next: preview and review</a> · <a href=\"/\">All posts</a></p>",
      ),
    )
  } catch {
    error => {
      let recovery = if request.target == "/settings" {
        "<p>Your settings are retained below. Reload the article if its version changed.</p>" +
        admin_settings_form(
          admin_hidden("token", token) +
          admin_hidden("name", fields.get("name").unwrap_or("")) +
          admin_hidden("version", fields.get("version").unwrap_or("")),
          fields.get("slug").unwrap_or(""),
          fields.get("listed").unwrap_or(""),
          fields.get("layout").unwrap_or(""),
        )
      } else if request.target == "/duplicate" {
        "<p>Your duplication fields are retained. Reload the original article if its version changed.</p>" +
        admin_duplicate_form(
          token,
          fields.get("name").unwrap_or(""),
          fields.get("version").unwrap_or(""),
          fields.get("slug").unwrap_or(""),
          fields.get("title").unwrap_or(""),
        )
      } else if request.target == "/import" {
        admin_import_form(
          token,
          fields.get("source").unwrap_or(""),
          fields.get("name").unwrap_or(""),
        )
      } else if request.target == "/fields" || request.target == "/preview" {
        let edit : PostFields = {
          title: fields.get("title").unwrap_or(""),
          description: fields.get("description").unwrap_or(""),
          date: fields.get("date").unwrap_or(""),
          tags: fields.get("tags").unwrap_or(""),
          body: fields.get("body").unwrap_or(""),
        }
        "<p>Your submitted fields are retained below. On a version conflict, copy them before reloading; retrying cannot overwrite the newer source.</p>" +
        admin_fields_form(
          admin_hidden("token", token) +
          admin_hidden("name", fields.get("name").unwrap_or("")) +
          admin_hidden("version", fields.get("version").unwrap_or("")),
          edit,
        )
      } else if request.target == "/save" {
        "<h2>Your submitted source</h2><p>Copy this text before reloading the current article. It has not been retried automatically.</p><textarea readonly aria-label=\"Submitted source\">\n" +
        escape_html(fields.get("content").unwrap_or("")) +
        "</textarea>"
      } else {
        ""
      }
      (
        400,
        admin_page(
          if request.target == "/settings" {
            "Could not save article settings"
          } else if request.target == "/duplicate" {
            "Could not duplicate article"
          } else if request.target == "/prepare-media" {
            "Could not prepare media storage"
          } else if request.target == "/import" {
            "Could not import media"
          } else if request.target == "/plan-production" {
            "Production inspection failed"
          } else if request.target == "/build-production" {
            "Production build failed"
          } else if request.target == "/build-preview" {
            "Preview build failed"
          } else if request.target == "/check" {
            "Validation failed"
          } else if request.target == "/preview" {
            "Could not preview"
          } else {
            "Could not save"
          },
          "<p class=\"notice\">" +
          escape_html(error.to_string()) +
          "</p>" +
          recovery +
          admin_recovery_links() +
          (if request.target == "/build-production" {
            admin_production_plan_form(token)
          } else {
            ""
          }) +
          "<p><a href=\"/\"><!--mp:ja-->記事へ戻る<!--mp:en-->Return to posts<!--mp:end--></a></p>",
        ),
      )
    }
  }
}

///|
fn admin_table_start(label : String) -> String {
  "<div class=\"table-scroll\" role=\"region\" aria-label=\"" +
  escape_html(label) +
  "\" tabindex=\"0\"><table>"
}
