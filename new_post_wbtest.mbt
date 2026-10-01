///|
test "draft creation serializes literal titles safely without inventing dates" {
  for
    title in [
      "First post", "月 & <tag>", "Quotes: \" and \\", "Line\n---\n# Not a heading",
    ] {
    let doc = parse_document(draft_source(title), "fallback")
    assert_eq(doc.title, title)
    assert_true(doc.draft)
    assert_eq(doc.date, None)
    assert_eq(doc.body, "\nWrite your article here.\n")
  }
  try draft_source(" \n\t") catch {
    _ => ()
  } noraise {
    _ => fail("empty title accepted")
  }
}
