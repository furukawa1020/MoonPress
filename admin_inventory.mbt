///|
fn admin_post_problems(problems : Array[PostProblem]) -> String {
  if problems.is_empty() {
    return ""
  }
  let out = StringBuilder()
  out.write_string(
    "<section aria-label=\"Source problems\"><h2>Sources needing attention</h2><p>These sources could not be listed. Fix them before building. Only safely readable Markdown files can be repaired here; other entries require a local file editor.</p><ul>",
  )
  for problem in problems {
    out.write_string(
      "<li><strong>" +
      escape_html(problem.source) +
      "</strong>: " +
      escape_html(problem.message),
    )
    if problem.editable {
      let name = problem.source[8:].to_owned()
      out.write_string(
        " <a href=\"/edit?name=" + url_component(name) + "\">Repair source</a>",
      )
    }
    out.write_string("</li>")
  }
  out.write_string("</ul></section>")
  out.to_string()
}
