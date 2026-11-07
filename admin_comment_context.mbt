///|
fn admin_comment_posts(input : String) -> Array[RestPost] {
  try {
    let content = open_authoring_subdirectory(input, "content")
    defer directory_close(content.fd)
    content.lock()
    rest_all_posts_at(input, content, unassigned=true)
  } catch {
    _ => []
  }
}

///|
fn admin_comment_post(id : Int, articles : Array[RestPost]) -> String {
  for post in articles {
    if post.document.wp_id == Some(id) {
      return "<a href=\"/edit?name=" +
        url_component(post.stem + ".md") +
        "\">" +
        escape_html(post.document.title) +
        " (" +
        id.to_string() +
        ")</a>"
    }
  }
  admin_i18n("記事を確認できません", "Article unavailable") +
  " (" +
  id.to_string() +
  ")"
}

///|
fn admin_comment_time(comment : NativeComment) -> String raise {
  let utc = rest_now_utc(instant=comment.created) + "Z"
  "<time datetime=\"" + utc + "\">" + utc + "</time>"
}

///|
fn admin_comment_root(
  comment : NativeComment,
  rows : Array[CommentRow],
) -> String {
  let mut root = comment.id
  let mut parent = comment.parent
  while parent is Some(id) {
    root = id
    parent = rows[id - 1].comment.parent
  }
  "<a href=\"/comment?id=" +
  root.to_string() +
  "\">" +
  admin_i18n("スレッドの先頭", "Thread root") +
  " (" +
  root.to_string() +
  ")</a>"
}
