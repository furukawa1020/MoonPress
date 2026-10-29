///|
fn wp_comment_can_edit(
  user : AccessPrincipal,
  row : CommentRow,
  articles : Array[RestPost],
) -> Bool raise {
  if role_capabilities(user.role).contains("moderate_comments") {
    return true
  }
  for article in articles {
    let doc = article.document
    if doc.wp_id == Some(row.comment.post) {
      return role_can_edit(user.role, user.id, doc.author, doc.kind, !doc.draft)
    }
  }
  false
}
