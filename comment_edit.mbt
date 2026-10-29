///|
fn comment_validate_edit(
  old : NativeComment,
  next : NativeComment,
) -> Unit raise {
  if {
      ..next,
      content: old.content,
      author_name: old.author_name,
      status: old.status,
    } !=
    old ||
    next == old ||
    old.status == "trash" {
    raise InvalidInput("Invalid comment edit")
  }
  comment_text(next.content, 8192)
  comment_text(next.author_name, 80)
  if next.author_name.any(c => c.is_control()) ||
    !["hold", "approved", "spam", "trash"].contains(next.status) {
    raise InvalidInput("Invalid comment edit fields")
  }
}
