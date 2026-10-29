///|
test "comment editing retains immutable identity and rejects invalid fields" {
  let old : NativeComment = {
    id: 1,
    post: 1,
    parent: None,
    author: 1,
    author_name: "A",
    content: "Text",
    status: "hold",
    created: 0L,
  }
  comment_validate_edit(old, { ..old, content: "New", })
  for
    next in [
      old,
      { ..old, post: 2, content: "New", },
      { ..old, parent: Some(2), content: "New", },
      { ..old, author: 2, content: "New", },
      { ..old, created: 1L, content: "New", },
      { ..old, content: "", },
      { ..old, author_name: "A\nB", },
    ] {
    assert_true(
      try {
        comment_validate_edit(old, next)
        false
      } catch {
        _ => true
      },
    )
  }
  assert_true(
    try {
      comment_validate_edit({ ..old, status: "trash", }, {
        ..old,
        content: "New",
      })
      false
    } catch {
      _ => true
    },
  )
}
