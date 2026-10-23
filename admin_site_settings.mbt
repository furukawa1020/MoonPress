///|
fn admin_site_settings_form(
  token : String,
  version : String,
  content : String,
) -> String {
  "<p><a href=\"/site-settings\">Reload current settings</a> · <a href=\"/workflow\">Preview and review production changes</a></p>" +
  "<p>Advanced site.json editor. Supported settings: base_url, feed, page_size, tag_page_size, tag_index, comments, collection_layout and redirects. Saving validates the settings schema only. Run the full site check and review the production plan before building. No build or deployment is performed.</p>" +
  "<form method=\"post\" action=\"/site-settings\">" +
  admin_hidden("token", token) +
  admin_hidden("version", version) +
  "<p>Expected version: <code>" +
  escape_html(version) +
  "</code>. The absent version creates a new file; it never overwrites an existing one.</p><label>Settings JSON<textarea name=\"content\" required>\n" +
  escape_html(content) +
  "</textarea></label><button>Save settings</button></form>"
}

///|
fn admin_site_settings(input : String, token : String) -> String raise {
  let snapshot = read_site_settings(input)
  let diagnostic = try {
    parse_site_config(snapshot.content) |> ignore
    ""
  } catch {
    error =>
      "<p class=\"notice\">Current settings need repair: " +
      escape_html(error.to_string()) +
      "</p>"
  }
  admin_page(
    "Site settings",
    (if snapshot.exists {
      "<p>Editing saved site.json.</p>"
    } else {
      "<p>No site.json exists. The suggested JSON below has not been saved.</p>"
    }) +
    diagnostic +
    admin_comment_display_form(token, snapshot) +
    admin_site_settings_form(
      token,
      snapshot.digest.unwrap_or("absent"),
      snapshot.content,
    ),
  )
}

///|
fn admin_site_settings_save(
  input : String,
  token : String,
  fields : Map[String, String],
) -> (Int, String) raise {
  let version = admin_field(fields, "version")
  let content = admin_field(fields, "content")
  try {
    if fields.length() != 3 {
      raise InvalidInput("Invalid settings fields")
    }
    let report = save_site_settings(input, version, content)
    (
      200,
      admin_page(
        "Settings save result",
        "<p>" +
        (if report.created {
          "Created site.json."
        } else if report.changed {
          "Saved site.json."
        } else {
          "Settings unchanged."
        }) +
        " Settings schema validated only. No build or deployment performed.</p><p>Current SHA-256: <code>" +
        report.digest +
        "</code>.</p><p><a href=\"/site-settings\">Reload current settings</a> · <a href=\"/workflow\">Check, preview and review before building</a></p>",
      ),
    )
  } catch {
    error =>
      (
        400,
        admin_page(
          "Could not save settings",
          "<p class=\"notice\">" +
          escape_html(error.to_string()) +
          "</p><p>Your submitted content and version are retained. Reload and compare current settings before retrying a stale edit.</p>" +
          admin_site_settings_form(token, version, content),
        ),
      )
  }
}

///|
fn admin_comment_display_form(
  token : String,
  snapshot : SiteSettingsSnapshot,
) -> String {
  let enabled = parse_site_config(snapshot.content).comments catch {
      _ => return ""
    }
  "<h2><!--mp:ja-->記事のコメント表示<!--mp:en-->Comments in article pages<!--mp:end--></h2><p>Comments in article pages: " +
  (if enabled { "enabled" } else { "disabled" }) +
  "</p><form method=\"post\" action=\"/comment-display\">" +
  admin_hidden("token", token) +
  admin_hidden("version", snapshot.digest.unwrap_or("absent")) +
  "<p><!--mp:ja-->承認済みで、現在公開されている記事のコメントだけを、次回のビルドに含めます。設定後にビルドと公開が必要です。<!--mp:en-->Only approved comments on currently public articles are included in the next build. Rebuild and publish after changing this setting.<!--mp:end--></p><button name=\"enabled\" value=\"" +
  (if enabled { "false" } else { "true" }) +
  "\">" +
  (if enabled {
    "<!--mp:ja-->表示しない<!--mp:en-->Hide comments<!--mp:end-->"
  } else {
    "<!--mp:ja-->承認済みコメントを表示<!--mp:en-->Show approved comments<!--mp:end-->"
  }) +
  "</button></form>"
}

///|
fn admin_comment_display_save(
  input : String,
  token : String,
  fields : Map[String, String],
) -> (Int, String) raise {
  if fields.length() != 3 {
    raise InvalidInput("Invalid display setting fields")
  }
  let enabled = match admin_field(fields, "enabled") {
    "true" => true
    "false" => false
    _ => raise InvalidInput("Invalid display setting")
  }
  let saved = read_site_settings(input)
  let expected = admin_field(fields, "version")
  require_settings_version(saved, expected)
  let value = @json.parse(saved.content)
  match value {
    Object(values) => values["comments"] = enabled.to_json()
    _ => raise InvalidInput("Settings must be an object")
  }
  save_site_settings(input, expected, value.stringify() + "\n") |> ignore
  (200, admin_site_settings(input, token))
}
