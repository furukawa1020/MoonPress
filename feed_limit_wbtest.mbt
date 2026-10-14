///|
test "feed selection is chronological bounded and preserves caller order" {
  let pages : Array[Page] = [
    {
      output: "old.html",
      document: parse_document(
        "---\n{\"date\":\"2020-01-01\"}\n---\n# Old", "old",
      ),
    },
    {
      output: "new.html",
      document: parse_document(
        "---\n{\"date\":\"2026-01-01\"}\n---\n# New", "new",
      ),
    },
    { output: "none.html", document: parse_document("# Undated", "none"), },
  ]
  assert_eq(selected_feed_pages(pages, Some(1))[0].output, "new.html")
  assert_eq(selected_feed_pages(pages, Some(5)).length(), 3)
  assert_eq(selected_feed_pages([], Some(1)).length(), 0)
  assert_eq(selected_feed_pages(pages, None)[0].output, "old.html")
  assert_eq(pages[0].output, "old.html")
}

///|
test "RSS limits reject null fractional wrong-type and out-of-range values" {
  for value in ["null", "0", "1001", "-1", "1.5", "true", "\"1\""] {
    assert_true(
      try {
        let _ = parse_site_config(
          "{\"base_url\":\"https://example.org/\",\"feed\":{\"title\":\"x\",\"description\":\"y\",\"limit\":" +
          value +
          "}}",
        )
        false
      } catch {
        _ => true
      },
    )
  }
  assert_eq(
    parse_site_config(
      "{\"base_url\":\"https://example.org/\",\"feed\":{\"title\":\"x\",\"description\":\"y\",\"limit\":1000}}",
    ).feed.unwrap().limit,
    Some(1000),
  )
}
