///|
fn native_comment_project(
  row : CommentRow,
  edit : Bool,
  embed : Bool,
  projection? : ((CommentRow) -> Json raise)? = None,
) -> Json raise {
  if projection is Some(project) {
    return project(row)
  }
  let value = native_comment_value(row, edit)
  if embed {
    rest_project(value, ["id", "author_name", "parent", "created", "content"])
  } else {
    value
  }
}
