///|
fn admin_media_replace_form(
  token : String,
  name : String,
  version : String,
) -> String {
  "<p><a href=\"/media-replace?name=" +
  url_component(name) +
  "\">Reload current media version</a> · <a href=\"/media\">Return to media</a> · <a href=\"/reference-outputs?scope=all&amp;output=" +
  url_component(name) +
  "\">Inspect saved references</a></p>" +
  "<form method=\"post\" action=\"/replace-media\" enctype=\"multipart/form-data\">" +
  admin_hidden("token", token) +
  admin_hidden("name", name) +
  admin_hidden("version", version) +
  "<p>Replace <code>" +
  escape_html(name) +
  "</code> at the same URL. Existing bytes will be replaced; keep a backup if needed. The selected file's name will not rename this asset.</p>" +
  "<p>Expected SHA-256: <code>" +
  escape_html(version) +
  "</code>. A newer edit will be refused. No build or deployment is performed.</p>" +
  "<label>Replacement file (complete request at most 8 MiB)<input type=\"file\" name=\"file\" required></label><button>Replace existing media</button></form>"
}

///|
fn admin_media_replace(
  input : String,
  name : String,
  token : String,
) -> String raise {
  let item = read_media(input, name)
  admin_page(
    "Replace media",
    "<p>Saved asset: <code>" +
    escape_html(item.source) +
    "</code> (\{item.bytes} bytes). Article URL: <code>" +
    escape_html(item.url) +
    "</code>. File contents are not displayed or served here.</p>" +
    admin_media_replace_form(token, name, item.digest),
  )
}

///|
fn admin_replace_upload(
  input : String,
  upload : AdminUpload,
  token : String,
) -> (Int, String) raise {
  let version = match upload.version {
    Some(version) => version
    None => raise InvalidInput("Media replacement requires an expected version")
  }
  try {
    let report = replace_media(input, upload.name, version, upload.bytes)
    (
      200,
      admin_page(
        "Media replacement result",
        "<p>" +
        (if report.changed { "Replaced " } else { "Unchanged " }) +
        escape_html(report.item.source) +
        " (\{report.item.bytes} bytes). URL unchanged. No build or deployment performed.</p>" +
        "<p>Current SHA-256: <code>" +
        report.item.digest +
        "</code>.</p>" +
        "<p>Inspect the production plan and review before building the new bytes.</p><p><a href=\"/workflow\">Writing and publishing steps</a> · <a href=\"/media\">Return to media</a></p>",
      ),
    )
  } catch {
    error =>
      (
        400,
        admin_page(
          "Could not replace media",
          "<p class=\"notice\">" +
          escape_html(error.to_string()) +
          "</p><p>The submitted version is retained. Reload and review the current asset if it changed; select a file again before retrying.</p>" +
          admin_media_replace_form(token, upload.name, version),
        ),
      )
  }
}
