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
    if key != "q" && key != "state" && key != "page" && key != "kind" {
      raise InvalidInput("Unknown post query field: " + key)
    }
  }
  let query = fields.get("q").unwrap_or("")
  let state = fields.get("state").unwrap_or("all")
  let kind = fields.get("kind").unwrap_or("all")
  let page = admin_page_number(fields.get("page").unwrap_or("1"))
  let inventory = inspect_posts(input)
  let matches = filter_post_kind(
    filter_posts(inventory.posts, query, state),
    kind,
  )
  let (start, end, pages) = admin_page_bounds(matches.length(), page)
  let out = StringBuilder()
  out.write_string(
    "<p class=\"notice\"><a href=\"/workflow\">Start here: write, preview, review and publish</a></p>",
  )
  out.write_string(admin_post_search_form(query, state, kind~))
  out.write_string(
    "<p>Showing \{end - start} of \{matches.length()} matching posts (\{inventory.posts.length()} valid total). Page \{page} of \{pages}.</p>",
  )
  if matches.is_empty() {
    out.write_string("<p>No matching posts.</p>")
  }
  out.write_string(
    "<p>Ready posts enter normal builds. Changes here do not deploy your site.</p>" +
    admin_table_start("Posts inventory") +
    "<thead><tr><th><!--mp:ja-->タイトル<!--mp:en-->Title<!--mp:end--></th><th>State</th><th><!--mp:ja-->ソース<!--mp:en-->Source<!--mp:end--></th></tr></thead><tbody>",
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
      escape_html(post.kind) +
      " · " +
      (if post.draft { "Draft" } else { "Ready" }) +
      (if post.listed { "" } else { " · unlisted" }) +
      "</td><td>" +
      escape_html(name) +
      "</td></tr>",
    )
  }
  out.write_string(
    "</tbody></table></div>" +
    admin_post_navigation(query, state, page, pages, kind~) +
    admin_post_problems(inventory.problems) +
    "<h2 id=\"new-draft\"><!--mp:ja-->新しい下書き<!--mp:en-->New draft<!--mp:end--></h2><form method=\"post\" action=\"/new\">" +
    admin_hidden("token", token) +
    "<label><!--mp:ja-->タイトル<!--mp:en-->Title<!--mp:end--><input name=\"title\" required></label><label>File stem (for example, first-post)<input name=\"slug\" required></label><button><!--mp:ja-->下書きをつくる<!--mp:en-->Create draft<!--mp:end--></button></form>",
  )
  admin_page(
    "Posts",
    out.to_string() +
    admin_check_form(token) +
    admin_build_form(token) +
    admin_production_plan_form(token) +
    admin_production_form(token),
  )
}
