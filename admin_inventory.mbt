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

///|
fn admin_posts(
  input : String,
  token : String,
  fields : Map[String, String],
) -> String raise {
  for key, _ in fields {
    if key != "q" && key != "state" && key != "page" {
      raise InvalidInput("Unknown post query field: " + key)
    }
  }
  let query = fields.get("q").unwrap_or("")
  let state = fields.get("state").unwrap_or("all")
  let page = admin_post_page(fields.get("page").unwrap_or("1"))
  let inventory = inspect_posts(input)
  let matches = filter_posts(inventory.posts, query, state)
  let pages = if matches.is_empty() {
    1
  } else {
    (matches.length() - 1) / 20 + 1
  }
  if page > pages {
    raise InvalidInput("Post page exceeds available pages")
  }
  let start = (page - 1) * 20
  let end = if start + 20 < matches.length() {
    start + 20
  } else {
    matches.length()
  }
  let out = StringBuilder()
  out.write_string(admin_post_search_form(query, state))
  out.write_string(
    "<p>Showing \{end - start} of \{matches.length()} matching posts (\{inventory.posts.length()} valid total). Page \{page} of \{pages}.</p>",
  )
  if matches.is_empty() {
    out.write_string("<p>No matching posts.</p>")
  }
  out.write_string(
    "<p>Ready posts enter normal builds. Changes here do not deploy your site.</p><table><thead><tr><th>Title</th><th>State</th><th>Source</th></tr></thead><tbody>",
  )
  for index = start; index < end; index = index + 1 {
    let post = matches[index]
    let name = post.source[8:].to_owned()
    out.write_string(
      "<tr><td><a href=\"/edit?name=" +
      url_component(name) +
      "\">" +
      escape_html(post.title) +
      "</a></td><td>" +
      (if post.draft { "Draft" } else { "Ready" }) +
      (if post.listed { "" } else { " · unlisted" }) +
      "</td><td>" +
      escape_html(name) +
      "</td></tr>",
    )
  }
  out.write_string(
    "</tbody></table>" +
    admin_post_navigation(query, state, page, pages) +
    admin_post_problems(inventory.problems) +
    "<h2>New draft</h2><form method=\"post\" action=\"/new\">" +
    admin_hidden("token", token) +
    "<label>Title<input name=\"title\" required></label><label>File stem (for example, first-post)<input name=\"slug\" required></label><button>Create draft</button></form>",
  )
  admin_page("Posts", out.to_string() + admin_check_form(token))
}
