///|
fn comment_public(row : CommentRow, rows : Array[CommentRow]) -> Bool {
  let mut current = row.comment
  let post = current.post
  let mut depth = 0
  while true {
    if current.status != "approved" || current.post != post {
      return false
    }
    let parent = current.parent.unwrap_or(0)
    if parent == 0 {
      return true
    }
    depth += 1
    if depth > 8 || parent < 1 || parent >= current.id || parent > rows.length() {
      return false
    }
    current = rows[parent - 1].comment
  }
  false
}
