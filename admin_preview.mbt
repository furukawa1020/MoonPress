///|
fn admin_body_preview(body : String) -> String {
  // Markdown never admits raw HTML. Disable generated destinations in this
  // body-only preview: output routes/assets are not served by the admin server.
  let rendered = render_markdown(body)
    .replace_all(old="<a href=", new="<a data-preview-href=")
    .replace_all(old="<img src=", new="<img data-preview-src=")
  "<section aria-label=\"Markdown body preview\"><h2>Unsaved body preview</h2><p class=\"notice\">Nothing was saved, built or deployed. This previews Markdown only, without the site theme, images or active links. Metadata and site links are validated separately when saving or checking the site.</p><article>" +
  rendered +
  "</article></section><h2>Continue editing</h2>"
}
