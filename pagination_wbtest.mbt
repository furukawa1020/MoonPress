///|
fn archive_fixture(name : String, date : String) -> Page raise {
  {
    output: name + ".html",
    document: parse_document(
      "---\n{\"date\":\"" + date + "\"}\n---\n# " + name,
      name,
    ),
  }
}

///|
test "pagination validates bounded integer settings" {
  for value in ["1", "1000", "2.0", "1e1"] {
    assert_true(
      parse_site_config(
        "{\"base_url\":\"https://example.org\",\"page_size\":" + value + "}",
      ).page_size
      is Some(_),
    )
  }
  for
    value in [
      "0", "-1", "1001", "2.5", "1e50", "null", "true", "\"2\"", "[]", "{}",
    ] {
    let rejected = try {
      let _ = parse_site_config(
        "{\"base_url\":\"https://example.org\",\"page_size\":" + value + "}",
      )
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
test "archives partition chronological pages without mutating input" {
  let pages = [
    archive_fixture("one", "2026-01-01"),
    archive_fixture("two", "2026-01-02"),
    archive_fixture("three", "2026-01-03"),
  ]
  let chunks = article_archives(pages, Some(2))
  assert_eq(chunks.map(c => c.output), ["articles.html", "articles-2.html"])
  assert_eq(chunks[0].members.map(p => p.output), ["three.html", "two.html"])
  assert_eq(chunks[1].members.map(p => p.output), ["one.html"])
  assert_eq(pages.map(p => p.output), ["one.html", "two.html", "three.html"])
  let first = render_archive(chunks[0])
  let last = render_archive(chunks[1])
  assert_true(first.contains("rel=\"next\" href=\"articles-2.html\""))
  assert_false(first.contains("rel=\"prev\""))
  assert_true(last.contains("rel=\"prev\" href=\"articles.html\""))
  assert_false(last.contains("rel=\"next\""))
  assert_true(last.contains("Page 2 of 2"))
}

///|
test "single exact and empty boundaries have no phantom archives" {
  let pages = [
    archive_fixture("one", "2026-01-01"),
    archive_fixture("two", "2026-01-02"),
  ]
  assert_eq(article_archives(pages, Some(2)).length(), 1)
  assert_eq(article_archives(pages, Some(1)).length(), 2)
  let empty = article_archives([], Some(2))
  assert_eq(empty.length(), 1)
  assert_true(render_archive(empty[0]).contains("Page 1 of 1"))
  let ordinary = article_archives(pages, None)[0]
  assert_eq(render_archive(ordinary), render_collection("Articles", pages))
  assert_eq(
    archive_dependencies(ordinary, "digest").to_json().stringify(),
    collection_dependencies(pages, "digest").to_json().stringify(),
  )
}
