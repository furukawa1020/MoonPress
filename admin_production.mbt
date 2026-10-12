///|
fn admin_production_output(input : String) -> String {
  input.trim_end(chars="/").to_owned() + "/.moonpress-build"
}

///|
fn admin_production_form(token : String) -> String {
  "<h2>Production files</h2><form method=\"post\" action=\"/build-production\">" +
  admin_hidden("token", token) +
  "<p>Compile saved ready articles and assets into <code>.moonpress-build</code> inside this site. Drafts and unsaved text are excluded. This creates local files; hosting deployment is a separate step.</p><button>Build production files</button></form>"
}

///|
fn admin_build_production(input : String, token : String) -> String raise {
  let output = admin_production_output(input)
  let report = compile_site(input, output)
  admin_page(
    "Production files built",
    "<p>Built saved ready articles; drafts excluded. No deployment performed.</p><p>Pages: \{report.pages}; written: \{report.written}; unchanged: \{report.skipped}; deleted: \{report.deleted}.</p><p>Local output: <code>" +
    escape_html(output) +
    "</code>. Use the documented hosting workflow to deploy these files. A successful build does not record a deployment.</p>" +
    admin_production_form(token),
  )
}

///|
fn admin_production_plan_form(token : String) -> String {
  "<h2>Inspect production changes</h2><form method=\"post\" action=\"/plan-production\">" +
  admin_hidden("token", token) +
  "<p>Validate saved ready articles and inspect planned changes to <code>.moonpress-build</code>. Drafts and unsaved text are excluded. No files or output directory are created.</p><button>Inspect production changes</button></form>"
}

///|
fn admin_production_changes(report : BuildReport) -> String {
  let out = StringBuilder()
  out.write_string(
    "<table><thead><tr><th>Action</th><th>Path</th><th>Reason</th></tr></thead><tbody>",
  )
  for change in report.changes {
    out.write_string(
      "<tr><td>" +
      escape_html(change.action) +
      "</td><td><code>" +
      escape_html(change.path) +
      "</code></td><td>" +
      escape_html(change.reason) +
      "</td></tr>",
    )
  }
  out.write_string("</tbody></table>")
  out.to_string()
}

///|
fn admin_plan_production(input : String, token : String) -> String raise {
  let output = admin_production_output(input)
  let report = compile_site(input, output, dry_run=true)
  admin_page(
    "Production changes inspected",
    "<p>Read-only inspection; drafts excluded. No files written or deployment performed.</p><p>Pages: \{report.pages}; would write: \{report.written}; unchanged: \{report.skipped}; would delete: \{report.deleted}.</p><p>Planned output: <code>" +
    escape_html(output) +
    "</code>. This is an observation of current files, not an approval or reservation. Building revalidates sources and output, so later changes can alter the result.</p>" +
    admin_production_changes(report) +
    admin_production_plan_form(token) +
    admin_production_form(token),
  )
}
