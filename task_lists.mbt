///|
fn task_item(text : String) -> (Bool, String)? {
  for marker in ["[ ] ", "[x] ", "[X] "] {
    if text.has_prefix(marker) {
      return Some((marker != "[ ] ", text[4:].to_owned()))
    }
  }
  None
}

///|
fn task_text(text : String) -> String {
  match task_item(text) {
    Some((_, content)) => content
    None => text
  }
}

///|
fn render_unordered_items(items : Array[String]) -> String {
  let out = StringBuilder()
  for item in items {
    match task_item(item) {
      None => out.write_string("<li>" + render_inline(item) + "</li>\n")
      Some((checked, content)) => {
        let label = inline_text(content)
        out.write_string(
          "<li class=\"task-list-item\"><input type=\"checkbox\" disabled" +
          (if checked { " checked" } else { "" }) +
          " aria-label=\"" +
          escape_html(if label.is_empty() { "Task" } else { label }) +
          "\"> " +
          render_inline(content) +
          "</li>\n",
        )
      }
    }
  }
  out.to_string()
}
