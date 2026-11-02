///|
test "anonymous author does not manufacture a user relation" {
  let comment : NativeComment = {
    id: 1,
    post: 1,
    parent: None,
    author: 0,
    author_name: "Reader",
    content: "Text",
    status: "approved",
    created: 0L,
  }
  match rest_comment_links(comment, [], "http://example.test/") {
    Object(fields) => assert_false(fields.contains("author"))
    _ => fail("Expected relationship object")
  }
}
