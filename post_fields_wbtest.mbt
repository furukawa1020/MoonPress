///|
test "structured editing preserves advanced fields and no-op source bytes" {
  let source = "---\r\n{\"title\":\"Original\",\"tags\":[\" b \",\"a\",\"a\"],\"draft\":true,\"listed\":false,\"layout\":\"post.html\",\"slug\":\"custom\"}\r\n---\r\n# Body\r\n"
  let edit = post_fields(source, "post.md")
  assert_eq(source_with_fields(source, "post.md", edit), source)
  let updated = source_with_fields(source, "post.md", {
    title: "New",
    date: "2026-10-03",
    description: "Summary",
    tags: "Moon,Bit\n web \nweb\n",
    body: "# Updated\r\n",
  })
  let doc = parse_document(updated, "post")
  assert_eq(doc.title, "New")
  assert_eq(doc.tags, ["web", "Moon,Bit"])
  assert_eq(doc.date, Some("2026-10-03"))
  assert_eq(doc.description, "Summary")
  assert_eq(doc.body, "# Updated\n")
  assert_true(doc.draft)
  assert_false(doc.listed)
  assert_eq(doc.layout, Some("post.html"))
  assert_eq(doc.slug, Some("custom"))
  let cleared = parse_document(
    source_with_fields(updated, "post.md", {
      ..edit,
      title: "",
      description: "",
      date: "",
      tags: "",
    }),
    "post",
  )
  assert_eq(cleared.title, "Body")
  assert_eq(cleared.tags, [])
  assert_eq(cleared.date, None)
}

///|
test "structured fields preserve inferred titles and reject invalid dates" {
  let source = "# Inferred\r\n"
  let edit = post_fields(source, "post.md")
  assert_eq(edit.title, "")
  assert_eq(source_with_fields(source, "post.md", edit), source)
  try
    source_with_fields(source, "post.md", { ..edit, date: "2026-02-30", })
  catch {
    _ => ()
  } noraise {
    _ => fail("Invalid date accepted")
  }
}
