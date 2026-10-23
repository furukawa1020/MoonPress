///|
test "comment capacity returns without touching storage" {
  let comment : NativeComment = {
    id: 1,
    post: 1,
    author: 1,
    author_name: "Reader",
    content: "Text",
    status: "hold",
    created: 0L,
  }
  let state : CommentState = {
    sequence: 4096,
    revision: "a".repeat(64),
    rows: [],
    bytes: 0,
  }
  assert_true(
    comment_append({ fd: -1, path: "unused", }, state, comment, "create")
    is None,
  )
  assert_true(
    comment_append(
      { fd: -1, path: "unused", },
      { ..state, sequence: 1, bytes: 16777216, },
      comment,
      "create",
    )
    is None,
  )
}
