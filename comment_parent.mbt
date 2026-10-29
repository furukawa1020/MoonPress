///|
fn comment_validate_parent(
  rows : Array[CommentRow],
  comment : NativeComment,
) -> Unit raise {
  let mut parent = comment.parent.unwrap_or(0)
  let mut upper = comment.id
  let mut depth = 0
  if parent < 0 {
    raise InvalidInput("Invalid comment parent")
  }
  while parent > 0 {
    depth += 1
    if depth > 8 || parent >= upper || parent > rows.length() {
      raise InvalidInput("Invalid comment ancestry")
    }
    let ancestor = rows[parent - 1].comment
    if ancestor.post != comment.post {
      raise InvalidInput("Comment parent belongs to another article")
    }
    upper = parent
    parent = ancestor.parent.unwrap_or(0)
  }
}
