///|
fn admin_page(title : String, body : String) -> String {
  "<!doctype html><html lang=\"en\"><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>" +
  escape_html(title) +
  " — MoonPress</title><style>body{font:17px/1.6 system-ui;max-width:64rem;margin:auto;padding:2rem;background:#f6f7fa;color:#182236}nav{padding:1rem 0;border-bottom:1px solid #ccd3de}a{color:#204ea5}table{width:100%;border-collapse:collapse}td,th{text-align:left;padding:.7rem;border-bottom:1px solid #ccd3de}form{margin:1.5rem 0;padding:1rem;background:white;border:1px solid #ccd3de;border-radius:.5rem}label{display:block;margin:.7rem 0}input,textarea,button{font:inherit;box-sizing:border-box}input,textarea{width:100%;padding:.5rem}textarea{min-height:24rem;font-family:monospace}button{padding:.5rem 1rem;cursor:pointer}input[type=hidden]{display:none}:focus-visible{outline:3px solid #bb6b10;outline-offset:3px}.notice{padding:1rem;background:#fff3d6}</style><nav><strong>MoonPress</strong> · <a href=\"/\">Posts</a> · Local administration</nav><h1>" +
  escape_html(title) +
  "</h1>" +
  body +
  "</html>"
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
fn admin_posts(input : String, token : String) -> String raise {
  let out = StringBuilder()
  out.write_string(
    "<p>Ready posts enter normal builds. Changes here do not deploy your site.</p><table><thead><tr><th>Title</th><th>State</th><th>Source</th></tr></thead><tbody>",
  )
  let inventory = inspect_posts(input)
  for post in inventory.posts {
    let name = post.source[8:].to_owned()
    out.write_string(
      "<tr><td><a href=\"/edit?name=" +
      url_component(name) +
      "\">" +
      escape_html(post.title) +
      "</a></td><td>" +
      (if post.draft { "Draft" } else { "Ready" }) +
      (if post.listed { "" } else { " · unlisted" }) +
      "</td><td>" +
      escape_html(name) +
      "</td></tr>",
    )
  }
  out.write_string(
    "</tbody></table>" +
    admin_post_problems(inventory.problems) +
    "<h2>New draft</h2><form method=\"post\" action=\"/new\">" +
    admin_hidden("token", token) +
    "<label>Title<input name=\"title\" required></label><label>File stem (for example, first-post)<input name=\"slug\" required></label><button>Create draft</button></form>",
  )
  admin_page("Posts", out.to_string() + admin_check_form(token))
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
  admin_page(
    "Edit " + name,
    editor +
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
    if request.target == "/" {
      return (200, admin_posts(input, token))
    }
    if request.target.has_prefix("/edit?") {
      let fields = admin_form(request.target[6:].to_owned())
      if fields.length() != 1 {
        raise InvalidInput("Invalid edit query")
      }
      return (200, admin_edit(input, admin_field(fields, "name"), token))
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
  try {
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
        "\">Continue editing</a> · <a href=\"/\">All posts</a></p>",
      ),
    )
  } catch {
    error => {
      let recovery = if request.target == "/fields" ||
        request.target == "/preview" {
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
          if request.target == "/check" {
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
          "<p><a href=\"/\">Return to posts</a></p>",
        ),
      )
    }
  }
}
