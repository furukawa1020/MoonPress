///|
fn native_comment_project(row : CommentRow, edit : Bool, embed : Bool) -> Json {
  let value = native_comment_value(row, edit)
  if embed {
    rest_project(value, ["id", "author_name", "created", "content"])
  } else {
    value
  }
}
