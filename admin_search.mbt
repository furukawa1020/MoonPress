///|
fn admin_post_page(value : String) -> Int raise {
  if value.is_empty() || value.length() > 8 {
    raise InvalidInput("Post page must be a positive decimal integer")
  }
  let mut page = 0
  for ch in value {
    if ch < '0' || ch > '9' {
      raise InvalidInput("Post page must be a positive decimal integer")
    }
    page = page * 10 + ch.to_int() - 48
  }
  if page == 0 {
    raise InvalidInput("Post page must be a positive decimal integer")
  }
  page
}

///|
fn admin_post_search_form(query : String, state : String) -> String {
  let out = StringBuilder()
  out.write_string(
    "<form method=\"get\" action=\"/\"><label>Search titles, filenames and tags<input name=\"q\" value=\"" +
    escape_html(query) +
    "\"></label><label>State<select name=\"state\">",
  )
  for
    (value, label) in [
      ("all", "All posts"),
      ("draft", "Drafts"),
      ("ready", "Ready for build"),
      ("unlisted", "Unlisted"),
    ] {
    out.write_string(
      "<option value=\"" +
      value +
      "\"" +
      (if value == state { " selected" } else { "" }) +
      ">" +
      label +
      "</option>",
    )
  }
  out.write_string(
    "</select></label><button>Search posts</button> <a href=\"/\">Clear filters</a></form>",
  )
  out.to_string()
}

///|
fn admin_post_navigation(
  query : String,
  state : String,
  page : Int,
  pages : Int,
) -> String {
  let out = StringBuilder()
  let prefix = "/?q=" +
    url_component(query) +
    "&amp;state=" +
    url_component(state) +
    "&amp;page="
  out.write_string("<nav aria-label=\"Post pages\">")
  if page > 1 {
    out.write_string(
      "<a rel=\"prev\" href=\"" +
      prefix +
      (page - 1).to_string() +
      "\">Previous posts</a> ",
    )
  }
  if page < pages {
    out.write_string(
      "<a rel=\"next\" href=\"" +
      prefix +
      (page + 1).to_string() +
      "\">Next posts</a>",
    )
  }
  out.write_string("</nav>")
  out.to_string()
}
