///|
fn admin_check_form(token : String) -> String {
  "<h2>Validate saved site</h2><form method=\"post\" action=\"/check\">" +
  admin_hidden("token", token) +
  "<p>Checks saved sources, layouts, metadata, links and planned routes. Unsaved editor text is not included. No output is written or deployed.</p><button name=\"mode\" value=\"ready\">Check normal build</button> <button name=\"mode\" value=\"drafts\">Check including drafts</button></form>"
}

///|
fn admin_check(
  input : String,
  token : String,
  include_drafts : Bool,
) -> String raise {
  let report = check_site(input, include_drafts~)
  let scope = if include_drafts {
    "Including drafts"
  } else {
    "Normal build (drafts excluded)"
  }
  admin_page(
    "Site validation passed",
    "<p>" +
    scope +
    "</p><p>Checked: \{report.pages} pages, \{report.outputs} planned outputs.</p><p>No files written or deployed. Existing output integrity and hosting configuration are not checked. External edits after this check require revalidation.</p>" +
    admin_check_form(token),
  )
}
