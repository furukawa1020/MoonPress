///|
test "duplicate keeps article content but resets publication identity" {
  let source = "---\r\n{\"title\":\"Original\",\"description\":\"Summary\",\"tags\":[\"tag\"],\"draft\":false,\"listed\":false,\"slug\":\"old-route\",\"date\":\"2026-10-12\",\"layout\":\"page.html\"}\r\n---\r\n# Body\r\n[original](old-route.html)\r\n"
  let doc = parse_document(
    duplicate_source(source, "original.md", "New <title>"),
    "copy",
  )
  assert_eq(doc.title, "New <title>")
  assert_true(doc.draft)
  assert_false(doc.listed)
  assert_eq(doc.date, None)
  assert_eq(doc.slug, None)
  assert_eq(doc.layout, Some("page.html"))
  assert_eq(doc.description, "Summary")
  assert_eq(doc.tags, ["tag"])
  assert_eq(doc.body, "# Body\n[original](old-route.html)\n")
}

///|
test "duplicate validates source and title" {
  for
    (source, title) in [
      ("# Body", "  "),
      ("---\n{broken\n---\n", "Title"),
      ("---\n{\"unknown\":true}\n---\n", "Title"),
    ] {
    let rejected = try {
      let _ = duplicate_source(source, "post.md", title)
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  let doc = parse_document(
    duplicate_source("# Body\n", "post.md", "Copy"),
    "copy",
  )
  assert_eq(doc.title, "Copy")
  assert_true(doc.draft)
  assert_eq(doc.body, "# Body\n")
}
