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
