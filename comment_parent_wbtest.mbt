///|
test "comment parent rejects future and cross-article references" {
  let root : NativeComment = {
    id: 1,
    post: 1,
    parent: None,
    author: 1,
    author_name: "A",
    content: "Text",
    status: "approved",
    created: 0L,
  }
  let rows : Array[CommentRow] = [{ comment: root, revision: "r", }]
  comment_validate_parent(rows, { ..root, id: 2, parent: Some(1), })
  for
    bad in [
      { ..root, id: 2, parent: Some(2), },
      { ..root, id: 2, post: 2, parent: Some(1), },
      { ..root, id: 2, parent: Some(-1), },
    ] {
    let rejected = try {
      comment_validate_parent(rows, bad)
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
test "legacy parent normalization" {
  let value = @json.parse(
    "{\"schema\":1,\"sequence\":1,\"previous\":\"absent\",\"action\":\"create\",\"comment\":{\"id\":1,\"post\":1,\"author\":1,\"author_name\":\"A\",\"content\":\"B\",\"status\":\"hold\",\"created\":\"0\"}}",
  )
  let e : CommentEvent = @json.from_json(value)
  assert_eq(e.comment.parent, None)
}
