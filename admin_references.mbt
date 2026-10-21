///|
fn admin_reference_source(source : String) -> String {
  if source.has_prefix("content/") {
    let name = source[8:].to_owned()
    if safe_output_name(name) && name.has_suffix(".md") && !name.has_prefix(".") {
      return "<a href=\"/edit?name=" +
        url_component(name) +
        "\">" +
        escape_html(source) +
        "</a>"
    }
  }
  "<code>" + escape_html(source) + "</code>"
}

///|
fn admin_reference_rows(title : String, edges : Array[ReferenceEdge]) -> String {
  let out = StringBuilder()
  out.write_string("<h2>" + escape_html(title) + " (\{edges.length()})</h2>")
  if edges.is_empty() {
    out.write_string(
      "<p>No authored references in this direction and scope. This does not prove deletion is safe.</p>",
    )
  } else {
    out.write_string(
      admin_table_start(title) +
      "<thead><tr><th scope=\"col\">Source</th><th scope=\"col\">Used by output</th><th scope=\"col\">Kind</th><th scope=\"col\">URL</th><th scope=\"col\">Target / fragment</th></tr></thead><tbody>",
    )
    for edge in edges {
      out.write_string(
        "<tr><td>" +
        admin_reference_source(edge.source) +
        "</td><td><code>" +
        escape_html(edge.output) +
        "</code></td><td>" +
        escape_html(edge.kind) +
        "</td><td><code>" +
        escape_html(edge.url) +
        "</code></td><td><code>" +
        escape_html(edge.target) +
        "</code> / " +
        escape_html(edge.fragment.unwrap_or("(none)")) +
        "</td></tr>",
      )
    }
    out.write_string("</tbody></table></div>")
  }
  out.to_string()
}

///|
fn admin_references(
  input : String,
  fields : Map[String, String],
) -> (Int, String) raise {
  for key, _ in fields {
    if key != "name" && key != "scope" {
      raise InvalidInput("Invalid reference query")
    }
  }
  let name = admin_field(fields, "name")
  let scope = fields.get("scope").unwrap_or("ready")
  if scope != "ready" && scope != "all" {
    raise InvalidInput("Reference scope must be ready or all")
  }
  let snapshot = read_post(input, name)
  let nav = "<p><a href=\"/edit?name=" +
    url_component(name) +
    "\">Return to article</a></p><p>Saved source only; unsaved editor text is excluded. No files written.</p><p><a href=\"/references?name=" +
    url_component(name) +
    "&amp;scope=ready\">Ready articles only</a> · <a href=\"/references?name=" +
    url_component(name) +
    "&amp;scope=all\">Include saved drafts</a></p><p>Current scope: " +
    (if scope == "all" { "including drafts" } else { "ready articles only" }) +
    ".</p><p>" +
    escape_html(reference_scope()) +
    "</p>"
  try {
    let document = parse_document(
      snapshot.content,
      name[:name.length() - 3].to_owned(),
      filename=snapshot.source,
    )
    if document.draft && scope == "ready" {
      return (
        200,
        admin_page(
          "Article references",
          nav +
          "<p class=\"notice\">This draft is excluded from the ready-only graph. Choose Include saved drafts to inspect its references. No graph validation was performed for this notice.</p>",
        ),
      )
    }
    let graph = inspect_references(input, include_drafts=scope == "all")
    let output = document.slug.unwrap_or(name[:name.length() - 3].to_owned()) +
      ".html"
    let report = query_references(graph, output)
    (
      200,
      admin_page(
        "Article references",
        nav +
        "<p>Output: <code>" +
        escape_html(report.route.name) +
        "</code></p>" +
        admin_reference_rows("Incoming references", report.incoming) +
        admin_reference_rows("Outgoing references", report.outgoing),
      ),
    )
  } catch {
    error =>
      (
        400,
        admin_page(
          "Reference inspection failed",
          nav +
          "<p class=\"notice\">No complete reference report is available. Fix the validation error and inspect again: " +
          escape_html(error.to_string()) +
          "</p>",
        ),
      )
  }
}
