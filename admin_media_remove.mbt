///|
fn admin_media_removal(
  input : String,
  name : String,
  token : String,
) -> String raise {
  let report = inspect_media_removal(input, name)
  let out = StringBuilder()
  out.write_string(
    "<p>Asset: <code>" +
    escape_html(report.item.source) +
    "</code> (\{report.item.bytes} bytes). SHA-256: <code>" +
    report.item.digest +
    "</code>.</p>",
  )
  out.write_string("<p>" + escape_html(report.scope) + "</p>")
  if report.blocked {
    out.write_string(
      "<h2>Removal blocked by saved references</h2><p>Remove these uses first, including drafts, then inspect again.</p><ul>",
    )
    for edge in report.references {
      out.write_string(
        "<li><code>" +
        escape_html(edge.source) +
        "</code> → <code>" +
        escape_html(edge.output) +
        "</code>: " +
        escape_html(edge.url) +
        "</li>",
      )
    }
    out.write_string("</ul>")
  } else {
    out.write_string(
      "<h2>No known references found</h2><p>This does not cover every possible use. Keep a backup before permanently removing the local file. Existing generated and hosted copies remain until you rebuild and deploy their removal.</p><form method=\"post\" action=\"/remove-media\">",
    )
    out.write_string(
      admin_hidden("token", token) +
      admin_hidden("name", name) +
      admin_hidden("review_id", report.review_id),
    )
    out.write_string(
      "<label><input style=\"width:auto\" type=\"checkbox\" name=\"ack\" value=\"confirm-unscanned-removal\" required> I checked CSS, unsupported HTML and external uses and accept permanent removal with no undo.</label><button>Remove this media permanently</button></form>",
    )
  }
  out.write_string(
    "<p><a href=\"/media\">Cancel and return to media</a> · <a href=\"/reference-outputs?scope=all&amp;output=" +
    url_component(name) +
    "\">Inspect saved references</a></p>",
  )
  admin_page("Review media removal", out.to_string())
}

///|
fn admin_remove_media(
  input : String,
  fields : Map[String, String],
) -> (Int, String) raise {
  if fields.length() != 4 {
    raise InvalidInput(
      "Removal requires exactly token, name, review_id and acknowledgement",
    )
  }
  let name = admin_field(fields, "name")
  try {
    let report = remove_media(
      input,
      name,
      admin_field(fields, "review_id"),
      acknowledge_unscanned=admin_field(fields, "ack") ==
        "confirm-unscanned-removal",
    )
    (
      200,
      admin_page(
        "Media removed",
        "<p>Permanently removed <code>" +
        escape_html(report.item.source) +
        "</code>. No undo. Generated files and hosting were not changed.</p><p><a href=\"/workflow#review\">Review and build production changes</a> · <a href=\"/media\">Return to media</a></p>",
      ),
    )
  } catch {
    error =>
      (
        400,
        admin_page(
          "Could not remove media",
          "<p class=\"notice\">" +
          escape_html(error.to_string()) +
          "</p><p><a href=\"/media-remove?name=" +
          url_component(name) +
          "\">Inspect removal again</a> · <a href=\"/media\">Return to media</a></p>",
        ),
      )
  }
}
