///|
test "preview paths remain flat and preserve encoded filenames" {
  assert_eq(preview_name("/"), "index.html")
  assert_eq(preview_name("/a+b.png?v=1"), "a+b.png")
  assert_eq(preview_name("/%E6%9C%88.png"), "月.png")
  for
    path in [
      "//etc", "/../x", "/%2e%2e", "/a%2fb", "/.moonpress.json", "/%00", "/%ff",
    ] {
    assert_true(
      try {
        preview_name(path) |> ignore
        false
      } catch {
        _ => true
      },
    )
  }
}

///|
test "preview response has isolated restrictive policy and binary length" {
  assert_eq(preview_mime("font.ttf"), "font/ttf")
  assert_eq(preview_mime("font.otf"), "font/otf")
  let response = preview_response(200, "text/css; charset=utf-8", b"a{}")
  let text = decode_text(response, "response")
  assert_true(text.contains("Content-Length: 3\r\n"))
  assert_true(text.contains("form-action 'none'"))
  assert_true(text.contains("default-src 'none'"))
  assert_true(text.contains("Cache-Control: no-store"))
}

///|
test "preview HEAD preserves length without body and stays preview-only" {
  let response = decode_text(
    preview_response(200, "image/png", b"abc", head=true),
    "HEAD",
  )
  assert_true(response.contains("Content-Length: 3\r\n"))
  assert_true(response.has_suffix("\r\n\r\n"))
  assert_eq(
    admin_headers(
      "HEAD / HTTP/1.1\r\nHost: localhost:8081\r\n\r\n",
      "localhost:8081",
      allow_head=true,
    ).verb,
    "HEAD",
  )
  assert_true(
    try {
      admin_headers(
        "HEAD / HTTP/1.1\r\nHost: localhost:8081\r\n\r\n", "localhost:8081",
      )
      |> ignore
      false
    } catch {
      _ => true
    },
  )
}

///|
test "conditional preview tags parse complete weak and strong lists" {
  for value in ["*", "\"abc\"", "W/\"abc\"", "\"other,tag\", W/\"abc\""] {
    assert_true(preview_etag_matches(value, "abc"))
  }
  for
    value in [
      "", "abc", "\"abc\",", "\"abc\", ", "\"abc\",bad", "\"abcd\"", "*, \"abc\"",
    ] {
    assert_false(preview_etag_matches(value, "abc"))
  }
  let response = decode_text(
    preview_response(304, "text/css", b"body", etag=Some("abc")),
    "304",
  )
  assert_true(response.contains("304 Not Modified"))
  assert_false(response.contains("Content-Length:"))
  assert_true(response.has_suffix("\r\n\r\n"))
}
