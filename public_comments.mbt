///|
fn render_comment_branch(
  rows : Array[CommentRow],
  parent : Int,
  depth : Int,
) -> String {
  if depth > 8 {
    return ""
  }
  let out = StringBuilder()
  for row in rows {
    let c = row.comment
    if c.parent.unwrap_or(0) != parent {
      continue
    }
    out.write_string(
      "<li id=\"comment-\{c.id}\"><p class=\"comment-author\">" +
      escape_html(c.author_name) +
      "</p><p>" +
      escape_html(c.content).replace_all(old="\n", new="<br>\n") +
      "</p>",
    )
    let children = render_comment_branch(rows, c.id, depth + 1)
    if !children.is_empty() {
      out.write_string("<ol class=\"comment-replies\">\n" + children + "</ol>")
    }
    out.write_string("</li>\n")
  }
  out.to_string()
}

///|
fn render_public_comments(rows : Array[CommentRow], post : Int) -> String {
  let visible = rows.filter(row => {
    row.comment.post == post && comment_public(row, rows)
  })
  if visible.is_empty() {
    return ""
  }
  visible.sort_by((a, b) => a.comment.id.compare(b.comment.id))
  "<section class=\"comments\" aria-label=\"Comments\"><h2>コメント / Comments</h2><ol>\n" +
  render_comment_branch(visible, 0, 0) +
  "</ol></section>\n"
}
