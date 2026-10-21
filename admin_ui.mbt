///|
fn admin_page(title : String, body : String) -> String {
  "<!doctype html><html lang=\"en\"><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>" +
  escape_html(title) +
  " — MoonPress</title><style>body{font:17px/1.6 system-ui;max-width:64rem;margin:auto;padding:2rem;background:#f6f7fa;color:#182236;overflow-wrap:anywhere}nav{padding:1rem 0;border-bottom:1px solid #ccd3de}a{color:#204ea5}.table-scroll{max-width:100%;overflow-x:auto;margin:1rem 0}table{width:100%;min-width:36rem;border-collapse:collapse}td,th{text-align:left;padding:.7rem;border-bottom:1px solid #ccd3de}form{margin:1.5rem 0;padding:1rem;background:white;border:1px solid #ccd3de;border-radius:.5rem}label{display:block;margin:.7rem 0}input,textarea,button{font:inherit;box-sizing:border-box;max-width:100%}input,textarea{width:100%;padding:.5rem}textarea{min-height:24rem;overflow-wrap:normal;font-family:monospace}button{padding:.5rem 1rem;cursor:pointer}input[type=hidden]{display:none}:focus-visible{outline:3px solid #bb6b10;outline-offset:3px}.notice{padding:1rem;background:#fff3d6}pre{max-width:100%;overflow-x:auto;white-space:pre-wrap}nav{overflow-wrap:normal}nav a{display:inline-block;padding:.25rem 0}@media(max-width:40rem){body{padding:1rem}td,th{padding:.45rem}form{padding:.75rem}textarea{min-height:16rem}button{white-space:normal}}.skip-link{position:absolute;left:-10000px;top:0}.skip-link:focus{left:1rem;top:1rem;background:white;padding:.5rem;z-index:10}@font-face{font-family:MoonPixel;src:url(/assets/font.woff) format(\"woff\");font-display:swap}body{background:#10152d;color:#f0eed9;font-family:MoonPixel,monospace;line-height:1.9}a{color:#b9e9dd}h1,h2,h3,strong{font-weight:400}nav{border-color:#8b92b4}form,.notice,.room-dialogue{background:#1b2442;color:#f0eed9;border:3px double #b1b7d2;border-radius:0;box-shadow:4px 4px 0 #05091a}input,textarea{background:#0c122b;color:#fff7dd;border:1px solid #8b92b4}button{background:#263c53;color:#fff7dd;border:3px double #b1b7d2;border-radius:0;font-family:inherit}button:hover,a:hover{color:#ffdc8a}td,th{border-color:#576280}:focus-visible{outline-color:#ffdc8a}.room-map ol{display:flex;flex-wrap:wrap;gap:8px 20px;padding:0;list-style:none}.room-map [aria-current=step]{color:#ffdc8a;text-decoration:underline double}.room-status{font-size:14px;color:#b9c8dc}.room-dialogue{padding:24px;margin:24px 0}.room-art{display:block;width:100%;height:auto;image-rendering:pixelated;margin:20px 0}.room-actions,.room-doors{display:flex;flex-wrap:wrap;gap:16px;margin:20px 0}.room-actions a,.room-doors a{display:block;border:3px double #b1b7d2;background:#1b2442;padding:12px 16px;text-decoration:none}.skip-link:focus{background:#10152d;color:white}textarea{font-family:monospace}@media(max-width:40rem){.room-dialogue{padding:14px}.room-doors{display:block}.room-doors a{margin:14px 0}}.room-window{height:220px;margin:20px 0;border:3px double #b1b7d2;background-image:url(/assets/rooms.webp);background-size:200%;image-rendering:pixelated}.room-window.entrance{background-position:0% 85%}.room-window.writing{background-position:30% 65%}.room-window.preview{background-position:62% 58%}.room-window.building{background-position:100% 55%}.room-window.departure{background-position:100% 0%}</style><a class=\"skip-link\" href=\"#main\">Skip to content</a><nav aria-label=\"Main navigation\"><strong>MoonPress</strong> · <a href=\"/workflow\">Start here</a> · <a href=\"/\">Posts</a> · <a href=\"/media\">Media</a> · <a href=\"/reference-outputs\">Output references</a> · <a href=\"/site-settings\">Site settings</a> · <a href=\"/publish\">Publish</a> · <a href=\"/rooms\">出版の冒険</a> · Local administration</nav><main id=\"main\" tabindex=\"-1\"><h1>" +
  escape_html(title) +
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
      ("title", "Title (blank: infer from body)", edit.title),
      ("description", "Description", edit.description),
      ("date", "Date (YYYY-MM-DD; blank: undated)", edit.date),
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
    "<label>Tags (one per line)<textarea name=\"tags\" style=\"min-height:5rem\">\n" +
    escape_html(edit.tags) +
    "</textarea></label><label>Markdown body<textarea name=\"body\">\n" +
    escape_html(edit.body) +
    "</textarea></label><button>Save article</button> <button formaction=\"/preview\">Preview body without saving</button></form>",
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
    "<p><a href=\"/workflow\">Writing and publishing steps</a>. Save your article, preview it, then set it ready for build.</p>" +
    "<p><a href=\"/references?name=" +
    url_component(name) +
    "\">Inspect saved article references</a> before changing its URL or removing a source.</p>" +
    editor +
    settings +
    admin_duplicate_form(token, name, snapshot.digest, "", copy_title) +
    "<details><summary>Advanced: edit Markdown and JSON source</summary><p>Use one editor at a time. Saving validates metadata; use the CLI to check links and preview the full site.</p><form method=\"post\" action=\"/save\">" +
    hidden +
    "<label>Source<textarea name=\"content\" spellcheck=\"false\" aria-label=\"Post source\">\n" +
    escape_html(snapshot.content) +
    "</textarea></label><button>Save source</button></form></details><form method=\"post\" action=\"/status\">" +
    hidden +
    "<p>These buttons change the saved source. Save the editor above first.</p><button name=\"state\" value=\"draft\">Set draft</button> <button name=\"state\" value=\"ready\">Set ready for build</button></form>",
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
          " (\{item.bytes} bytes). No deployment performed.</p><label>Markdown snippet<textarea readonly rows=\"2\" style=\"min-height:4rem\">\n" +
          escape_html(media_snippet(item)) +
          "</textarea></label><p><a href=\"/media\">Return to media</a></p>",
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
        "\">Continue editing</a> · <a href=\"/workflow\">Next: preview and review</a> · <a href=\"/\">All posts</a></p>",
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
          (if request.target == "/build-production" {
            admin_production_plan_form(token)
          } else {
            ""
          }) +
          "<p><a href=\"/\">Return to posts</a></p>",
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
