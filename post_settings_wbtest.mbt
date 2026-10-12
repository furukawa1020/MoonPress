///|
test "article settings preserve content and exact no-op bytes" {
  let source = "---\r\n{\"title\":\"Original\",\"description\":\"Summary\",\"tags\":[\"tag\"],\"draft\":true,\"listed\":false,\"slug\":\"old\",\"date\":\"2026-10-12\",\"layout\":\"post.html\"}\r\n---\r\n# Body\r\n"
  let settings = post_settings(source)
  assert_eq(settings.slug, "old")
  assert_false(settings.listed)
  assert_eq(source_with_settings(source, "post.md", settings), source)
  let doc = parse_document(
    source_with_settings(source, "post.md", {
      slug: "新しいURL",
      listed: true,
      layout: "",
    }),
    "post",
  )
  assert_eq(doc.slug, Some("新しいURL"))
  assert_true(doc.listed)
  assert_eq(doc.layout, None)
  assert_true(doc.draft)
  assert_eq(doc.title, "Original")
  assert_eq(doc.description, "Summary")
  assert_eq(doc.tags, ["tag"])
  assert_eq(doc.date, Some("2026-10-12"))
  assert_eq(doc.body, "# Body\n")
}

///|
test "settings support filename/default layout without adding defaults on no-op" {
  let source = "# Plain\r\n"
  let settings = post_settings(source)
  assert_eq(settings.slug, "")
  assert_eq(settings.layout, "")
  assert_true(settings.listed)
  assert_eq(source_with_settings(source, "plain.md", settings), source)
  let changed = source_with_settings(source, "plain.md", {
    ..settings,
    layout: "other.html",
  })
  let (metadata, _) = document_parts(changed, "plain.md")
  match metadata {
    Object(fields) => assert_false(fields.contains("listed"))
    _ => fail("object expected")
  }
  let reset = parse_document(
    source_with_settings(changed, "plain.md", settings),
    "plain",
  )
  assert_eq(reset.layout, None)
  assert_eq(reset.slug, None)
  assert_eq(reset.body, "# Plain\n")
}

///|
test "settings reject invalid routes and layout names with the compiler grammar" {
  for
    edit in [
      { slug: "../outside", listed: true, layout: "", },
      { slug: "has space", listed: true, layout: "", },
      { slug: "bad%20", listed: true, layout: "", },
      { slug: "", listed: true, layout: "file.js", },
      { slug: "", listed: true, layout: "../post.html", },
      { slug: "", listed: true, layout: ".hidden.html", },
    ] {
    let rejected = try {
      let _ = source_with_settings("# Body", "post.md", edit)
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  let rejected = try {
    let _ = post_settings("---\n{\"unknown\":true}\n---\n")
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}
