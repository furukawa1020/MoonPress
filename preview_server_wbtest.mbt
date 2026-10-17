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
