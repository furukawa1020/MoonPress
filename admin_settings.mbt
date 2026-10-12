///|
fn admin_settings_form(
  hidden : String,
  slug : String,
  listed : String,
  layout : String,
) -> String {
  let out = StringBuilder()
  out.write_string(
    "<h2>Article URL and layout</h2><form method=\"post\" action=\"/settings\">" +
    hidden +
    "<p>These settings apply to saved source and preserve the body and draft state. Save other editor changes first. Validate the saved site after changing URLs or layouts; links may need updating. No redirect or deployment is created.</p><label>Output URL stem (blank: source filename)<input name=\"slug\" value=\"" +
    escape_html(slug) +
    "\"></label><label>Article lists<select name=\"listed\">",
  )
  if listed != "yes" && listed != "no" {
    out.write_string(
      "<option selected value=\"" +
      escape_html(listed) +
      "\">Invalid submitted value: " +
      escape_html(listed) +
      "</option>",
    )
  }
  for
    (value, label) in [
      ("yes", "Include in article lists"),
      ("no", "Unlisted (still built and publicly reachable)"),
    ] {
    out.write_string(
      "<option value=\"" +
      value +
      "\"" +
      (if listed == value { " selected" } else { "" }) +
      ">" +
      label +
      "</option>",
    )
  }
  out.write_string(
    "</select></label><label>Named layout filename (blank: default layout.html)<input name=\"layout\" value=\"" +
    escape_html(layout) +
    "\"></label><button>Save article settings</button></form>",
  )
  out.to_string()
}

///|
fn admin_submitted_settings(fields : Map[String, String]) -> PostSettings raise {
  let listed = admin_field(fields, "listed")
  if listed != "yes" && listed != "no" {
    raise InvalidInput("Article listing must be yes or no")
  }
  {
    slug: admin_field(fields, "slug"),
    listed: listed == "yes",
    layout: admin_field(fields, "layout"),
  }
}
