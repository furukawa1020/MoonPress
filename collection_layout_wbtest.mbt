///|
test "collection layout is optional and validates the shared filename grammar" {
  assert_eq(
    parse_site_config("{\"base_url\":\"https://example.org\"}").collection_layout,
    None,
  )
  for name in ["archive.html", "一覧.html"] {
    assert_eq(
      parse_site_config(
        "{\"base_url\":\"https://example.org\",\"collection_layout\":\"" +
        name +
        "\"}",
      ).collection_layout,
      Some(name),
    )
  }
  for
    value in [
      "null", "true", "42", "[]", "\"\"", "\"../x.html\"", "\"a/b.html\"", "\".x.html\"",
      "\"x.txt\"", "\"a b.html\"",
    ] {
    try
      parse_site_config(
        "{\"base_url\":\"https://example.org\",\"collection_layout\":" +
        value +
        "}",
      )
    catch {
      _ => ()
    } noraise {
      _ => fail("expected invalid collection layout: " + value)
    }
  }
}

///|
test "collection and index dependencies use the selected layout identity" {
  let archive = article_archives([], None)[0]
  assert_eq(archive_dependencies(archive, "digest")[1].name, "layout.html")
  assert_eq(
    archive_dependencies(archive, "digest", layout_source="layouts/list.html")[1].name,
    "layouts/list.html",
  )
  assert_eq(
    tag_index_dependencies([], "digest", layout_source="layouts/list.html")[1].name,
    "layouts/list.html",
  )
}
