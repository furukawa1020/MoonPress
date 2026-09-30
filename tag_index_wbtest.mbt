///|
test "tag index escapes labels and links to first archive with explicit counts" {
  let tags : Array[TagSummary] = [
    { name: "月<&", count: 2, },
    { name: "a", count: 1, },
  ]
  let html = render_tag_index(tags)
  assert_true(
    html.contains("href=\"" + tag_filename("月<&") + "\">月&lt;&amp;</a>"),
  )
  assert_true(html.contains("(2 articles)"))
  assert_true(html.contains("(1 article)"))
  assert_eq(
    render_tag_index([]),
    "<h1>Tags</h1>\n<ul class=\"tag-index\">\n</ul>\n",
  )
  assert_false(
    tag_index_dependencies(tags, "layout")[2].digest ==
    tag_index_dependencies(
      [{ name: "月<&", count: 1, }, { name: "a", count: 1, }],
      "layout",
    )[2].digest,
  )
}

///|
test "tag index configuration is opt-in and strictly boolean" {
  assert_false(
    parse_site_config("{\"base_url\":\"https://example.org/\"}").tag_index,
  )
  assert_true(
    parse_site_config(
      "{\"base_url\":\"https://example.org/\",\"tag_index\":true}",
    ).tag_index,
  )
  for value in ["null", "0", "\"true\"", "[]"] {
    let rejected = try {
      let _ = parse_site_config(
        "{\"base_url\":\"https://example.org/\",\"tag_index\":" + value + "}",
      )
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}
