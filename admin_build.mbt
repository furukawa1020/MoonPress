///|
fn admin_build_form(token : String) -> String {
  "<h2>Full-site preview files</h2><form method=\"post\" action=\"/build-preview\">" +
  admin_hidden("token", token) +
  "<p>Compile saved articles, including drafts, with the site theme and assets into <code>.moonpress-preview</code> inside this site. This writes local preview files only. Unsaved editor text is excluded; nothing is deployed.</p><button>Build full preview files</button></form>"
}

///|
fn admin_build_preview(input : String, token : String) -> String raise {
  let output = input.trim_end(chars="/").to_owned() + "/.moonpress-preview"
  let report = compile_site(input, output, include_drafts=true)
  admin_page(
    "Full preview files built",
    "<p>Built from saved sources, including drafts. No deployment performed.</p><p>Pages: \{report.pages}; written: \{report.written}; unchanged: \{report.skipped}; deleted: \{report.deleted}.</p><p>Open the generated HTML files with your local file browser in <code>" +
    escape_html(output) +
    "</code>. This directory can contain private draft content; do not publish it as your production site. Generated project HTML is not served on the administration origin.</p>" +
    admin_build_form(token),
  )
}
