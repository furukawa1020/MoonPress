///|
test "media replacement multipart requires exactly a versioned upload" {
  let bytes = b"\x00\xff\r\n--testX"
  let version = digest_bytes(b"old")
  let body = upload_test_part("version", @utf8.encode(version)) +
    upload_test_body(bytes)
  let upload = admin_multipart(body, "test", replacing=true)
  assert_eq(upload.version, Some(version))
  assert_eq(upload.bytes, bytes)
  assert_eq(admin_multipart(upload_test_body(bytes), "test").version, None)
  for
    bad in [
      upload_test_body(bytes),
      upload_test_part("version", b"x") + body,
      upload_test_part("extra", b"x") + body,
      upload_test_part("version", @utf8.encode("a".repeat(65))) +
      upload_test_body(bytes),
    ] {
    assert_true(
      try {
        admin_multipart(bad, "test", replacing=true) |> ignore
        false
      } catch {
        _ => true
      },
    )
  }
  assert_true(
    try {
      admin_multipart(body, "test") |> ignore
      false
    } catch {
      _ => true
    },
  )
}

///|
test "media replacement form escapes retained values and keeps fixed name" {
  let html = admin_media_replace_form("<token>", "月&x.png", "<version>")
  assert_true(html.contains("value=\"&lt;token&gt;\""))
  assert_true(html.contains("value=\"&lt;version&gt;\""))
  assert_true(html.contains("name=\"name\" value=\"月&amp;x.png\""))
  assert_true(html.contains("/media-replace?name=%E6%9C%88%26x.png"))
  assert_true(html.contains("scope=all&amp;output=%E6%9C%88%26x.png"))
  assert_false(html.contains("<version>"))
}

///|
test "media replacement route keeps multipart size and origin constraints" {
  let base = "POST /replace-media HTTP/1.1\r\nHost: 127.0.0.1:8080\r\nOrigin: http://127.0.0.1:8080\r\nContent-Type: multipart/form-data; boundary=test\r\nContent-Length: "
  assert_eq(
    admin_headers(base + "8388608\r\n\r\n", "127.0.0.1:8080").boundary,
    Some("test"),
  )
  for
    raw in [
      base + "8388609\r\n\r\n",
      base.replace_all(
        old="Origin: http://127.0.0.1:8080",
        new="Origin: https://evil.test",
      ) +
      "1\r\n\r\n",
      base.replace_all(old="/replace-media", new="/other") + "1\r\n\r\n",
    ] {
    assert_true(
      try {
        admin_headers(raw, "127.0.0.1:8080") |> ignore
        false
      } catch {
        _ => true
      },
    )
  }
}
