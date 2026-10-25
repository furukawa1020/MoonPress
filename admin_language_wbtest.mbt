///|
test "language negotiation weights regional tags and preserves explicit preference" {
  for
    (header, expected) in [
      ("", ""),
      ("ja-JP, en;q=0.5", "ja"),
      ("en-US,en;q=0.9,ja;q=0.2", "en"),
      ("en;q=0.2,ja;q=0.9", "ja"),
      ("fr-FR", "en"),
      ("fr;q=1,ja;q=0.7", "ja"),
      ("ja;q=0,en;q=0.3", "en"),
      ("en;q=0,*;q=0.7", "ja"),
      ("ja;q=broken,en;q=0.1", "en"),
      ("JA-jp;q=0.800,en;q=0.7", "ja"),
      ("ja;q=0.7,en;q=0.7", "ja"),
      ("en;q=0.7,ja;q=0.7", "en"),
    ] {
    assert_eq(admin_browser_language(header), expected)
  }
  assert_eq(admin_language("ja", "unrelated=x; moonpress-language=en"), "en")
  assert_eq(admin_language("en", "moonpress-language=ja"), "ja")
  assert_eq(admin_language("ja", "moonpress-language=auto"), "ja")
  assert_eq(admin_language("en", "moonpress-language=unknown"), "en")
  assert_eq(
    admin_language("en", "moonpress-language=ja; moonpress-language=en"),
    "en",
  )
  assert_eq(admin_language_quality("1.001"), None)
  assert_eq(admin_language_quality("0.1234"), None)
}

///|
test "language rendering changes only marked application copy" {
  let content = "<textarea>" +
    escape_html("Media <!--mp:ja-->private<!--mp:en-->unchanged<!--mp:end-->") +
    "</textarea>"
  let html = admin_page(
    "編集データの案内所",
    admin_i18n("画面", "Screen") + content,
    title_en="Source editing recovery",
  )
  let en = admin_render_language(html, "en")
  let ja = admin_render_language(html, "ja")
  assert_true(en.contains("<html lang=\"en\">"))
  assert_true(en.contains("<h1>Source editing recovery</h1>"))
  assert_true(en.contains(content))
  assert_true(ja.contains(content))
  assert_false(en.contains("<!--mp:"))
  assert_true(ja.contains("<h1>編集データの案内所</h1>"))
  assert_true(ja.contains("画面"))
  assert_false(en.contains("画面"))
}

///|
test "language return paths cannot redirect outside administration" {
  for
    path in [
      "https://evil.test/", "//evil.test/", "/\\evil.test/", "/edit\r\nX: injected",
      "/export-production", "/assets/logo.jpg",
    ] {
    assert_eq(admin_language_target(path), "/rooms")
  }
  assert_eq(
    admin_language_target("/edit?name=%E6%9C%88.md"),
    "/edit?name=%E6%9C%88.md",
  )
  assert_eq(admin_language_target("/comment?id=7"), "/comment?id=7")
  assert_eq(
    admin_language_target("/comments?status=spam&page=2"),
    "/comments?status=spam&page=2",
  )
  let request = admin_headers(
    "GET /language/en?return=%2Fedit%3Fname%3Dmoon.md HTTP/1.1\r\nHost: 127.0.0.1:8080\r\nAccept-Language: ja\r\nCookie: moonpress-language=en\r\n\r\n",
    "127.0.0.1:8080",
  )
  assert_eq(request.language, "en")
  let response = decode_text(admin_language_response(request), "test")
  assert_true(response.contains("303 See Other\r\n"))
  assert_true(response.contains("Location: /edit?name=moon.md\r\n"))
  assert_true(response.contains("HttpOnly; SameSite=Strict"))
}
