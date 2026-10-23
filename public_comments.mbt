///|
fn render_public_comments(rows : Array[CommentRow], post : Int) -> String {
  let visible = rows.filter(row => {
    row.comment.post == post && row.comment.status == "approved"
  })
  if visible.is_empty() {
    return ""
  }
  visible.sort_by((a, b) => a.comment.id.compare(b.comment.id))
  let out = StringBuilder()
  out.write_string(
    "<section class=\"comments\" aria-label=\"Comments\"><h2>コメント / Comments</h2><ol>\n",
  )
  for row in visible {
    let c = row.comment
    out.write_string(
      "<li id=\"comment-\{c.id}\"><p class=\"comment-author\">" +
      escape_html(c.author_name) +
      "</p><p>" +
      escape_html(c.content).replace_all(old="\n", new="<br>\n") +
      "</p></li>\n",
    )
  }
  out.write_string("</ol></section>\n")
  out.to_string()
}
