///|
fn admin_output_reference_url(scope : String, name : String?) -> String {
  "/reference-outputs?scope=" +
  url_component(scope) +
  (match name {
    Some(name) => "&amp;output=" + url_component(name)
    None => ""
  })
}

///|
fn admin_reference_summary_table(
  report : ReferenceSummary,
  scope : String,
  page : Int,
) -> String raise {
  let (start, end, pages) = admin_page_bounds(report.routes.length(), page)
  let out = StringBuilder()
  out.write_string(
    "<p>Outputs: \{report.routes.length()}; authored edges: \{report.edges}. Page \{page} of \{pages}.</p>" +
    "<p>Incoming/outgoing counts include self references. Other referring outputs counts distinct consumers excluding this output. Zero counts do not prove deletion safety.</p>" +
    "<table><thead><tr><th scope=\"col\">Output</th><th scope=\"col\">Kind</th><th scope=\"col\">Incoming</th><th scope=\"col\">Outgoing</th><th scope=\"col\">Self</th><th scope=\"col\">Other referring outputs</th></tr></thead><tbody>",
  )
  for i = start; i < end; i = i + 1 {
    let row = report.routes[i]
    out.write_string(
      "<tr><td><a href=\"" +
      admin_output_reference_url(scope, Some(row.route.name)) +
      "\">" +
      escape_html(row.route.name) +
      "</a></td><td>" +
      escape_html(row.route.kind) +
      "</td><td>\{row.incoming}</td><td>\{row.outgoing}</td><td>\{row.self_references}</td><td>\{row.referring_outputs}</td></tr>",
    )
  }
  out.write_string("</tbody></table><p>")
  if page > 1 {
    out.write_string(
      "<a href=\"" +
      admin_output_reference_url(scope, None) +
      "&amp;page=\{page - 1}\">Previous outputs</a> ",
    )
  }
  if page < pages {
    out.write_string(
      "<a href=\"" +
      admin_output_reference_url(scope, None) +
      "&amp;page=\{page + 1}\">Next outputs</a>",
    )
  }
  out.write_string("</p>")
  out.to_string()
}

///|
fn admin_output_references(
  input : String,
  fields : Map[String, String],
) -> (Int, String) raise {
  for key, _ in fields {
    if key != "scope" && key != "output" && key != "page" {
      raise InvalidInput("Invalid output reference query")
    }
  }
  let scope = fields.get("scope").unwrap_or("ready")
  if scope != "ready" && scope != "all" {
    raise InvalidInput("Reference scope must be ready or all")
  }
  let name = fields.get("output")
  if name is Some(name) {
    if !safe_output_name(name) || fields.contains("page") {
      raise InvalidInput("Use an exact output filename without pagination")
    }
  }
  let page = admin_page_number(fields.get("page").unwrap_or("1"))
  let nav = "<p>Saved sources only; no files written. Current scope: " +
    (if scope == "all" { "including drafts" } else { "ready articles only" }) +
    ".</p><p><a href=\"" +
    admin_output_reference_url("ready", name) +
    "\">Ready articles only</a> · <a href=\"" +
    admin_output_reference_url("all", name) +
    "\">Include saved drafts</a> · <a href=\"" +
    admin_output_reference_url(scope, None) +
    "\">All output counts</a></p><p>" +
    escape_html(reference_scope()) +
    "</p>"
  try {
    let graph = inspect_references(input, include_drafts=scope == "all")
    let body = match name {
      None =>
        admin_reference_summary_table(summarize_references(graph), scope, page)
      Some(name) => {
        let report = query_references(graph, name)
        "<p>Output: <code>" +
        escape_html(report.route.name) +
        "</code>; kind: " +
        escape_html(report.route.kind) +
        "</p><p>Source: " +
        (match report.route.source {
          Some(source) => admin_reference_source(source)
          None => "(generated)"
        }) +
        "</p>" +
        (match report.route.target {
          Some(target) =>
            "<p>Redirect terminal target: <a href=\"" +
            admin_output_reference_url(scope, Some(target)) +
            "\">" +
            escape_html(target) +
            "</a></p>"
          None => ""
        }) +
        admin_reference_rows("Incoming references", report.incoming) +
        admin_reference_rows("Outgoing references", report.outgoing)
      }
    }
    (200, admin_page("Output references", nav + body))
  } catch {
    error =>
      (
        400,
        admin_page(
          "Reference inspection failed",
          nav +
          "<p class=\"notice\">No complete reference report is available. Fix the validation error or choose an included output: " +
          escape_html(error.to_string()) +
          "</p>",
        ),
      )
  }
}
