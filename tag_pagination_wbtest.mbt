///|
test "tag pagination shares partitioning but has independent routes and labels" {
  let pages = [
    archive_fixture("one", "2026-01-01"),
    archive_fixture("two", "2026-01-02"),
  ]
  let archives = tag_archives(pages, Some(1), "月<&")
  let first = tag_filename("月<&")
  let second = first[:first.length() - 5].to_owned() + "-2.html"
  assert_eq(archives.map(a => a.output), [first, second])
  assert_eq(archives[0].members[0].output, "two.html")
  let html = render_archive(archives[0])
  assert_true(html.contains("月&lt;&amp;"))
  assert_true(html.contains("aria-label=\"Tag pages\""))
  assert_true(html.contains("href=\"" + second + "\""))
  assert_true(render_archive(archives[1]).contains("href=\"" + first + "\""))
  let plain = tag_archives(pages, None, "月")[0]
  assert_eq(render_archive(plain), render_collection("月", pages))
  assert_eq(
    archive_dependencies(plain, "layout").to_json().stringify(),
    collection_dependencies(pages, "layout").to_json().stringify(),
  )
  let longest = tag_archives(pages, Some(1), String::make(96, 'x'))
  assert_true(longest.all(a => safe_output_name(a.output)))
}

///|
test "tag page size validation shares integer bounds independently" {
  let cfg = parse_site_config(
    "{\"base_url\":\"https://example.org\",\"page_size\":3,\"tag_page_size\":1}",
  )
  assert_eq(cfg.page_size, Some(3))
  assert_eq(cfg.tag_page_size, Some(1))
  for value in ["0", "1001", "null", "true", "1.5", "\"2\""] {
    let rejected = try {
      let _ = parse_site_config(
        "{\"base_url\":\"https://example.org\",\"tag_page_size\":" + value + "}",
      )
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}
