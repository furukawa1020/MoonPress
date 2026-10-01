///|
test "draft state changes preserve metadata and normalized body" {
  let source = "---\r\n{\"title\":\"Moon\",\"description\":\"Desc\",\"tags\":[\"x\"],\"listed\":false,\"layout\":\"post.html\",\"date\":\"2026-01-01\",\"slug\":\"moon\",\"draft\":true}\r\n---\r\n# Body\r\n\r\n---\r\ncode\r\n"
  let before = parse_document(source, "x")
  let after = parse_document(source_with_draft(source, "x", false), "x")
  assert_false(after.draft)
  assert_eq(after.title, before.title)
  assert_eq(after.description, before.description)
  assert_eq(after.tags, before.tags)
  assert_eq(after.listed, before.listed)
  assert_eq(after.layout, before.layout)
  assert_eq(after.date, before.date)
  assert_eq(after.slug, before.slug)
  assert_eq(after.body, before.body)
  assert_eq(source_with_draft(source, "x", true), source)
}

///|
test "plain sources and end-of-file frontmatter can change state" {
  for source in ["# Plain\n", "---\n{\"draft\":false}\n---", ""] {
    let updated = source_with_draft(source, "x", true)
    assert_true(parse_document(updated, "x").draft)
    assert_eq(
      parse_document(updated, "x").body,
      parse_document(source, "x").body,
    )
    assert_eq(source_with_draft(updated, "x", true), updated)
  }
  try source_with_draft("---\n{\"typo\":true}\n---\nbody", "x", true) catch {
    _ => ()
  } noraise {
    _ => fail("invalid metadata accepted")
  }
}
