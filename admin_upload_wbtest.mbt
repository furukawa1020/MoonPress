///|
fn upload_test_part(name : String, value : Bytes) -> Bytes {
  @utf8.encode(
    "--test\r\nContent-Disposition: form-data; name=\"" + name + "\"\r\n\r\n",
  ) +
  value +
  b"\r\n"
}

///|
fn upload_test_body(file : Bytes) -> Bytes {
  upload_test_part("token", b"token") +
  upload_test_part("name", @utf8.encode("月.png")) +
  b"--test\r\nContent-Disposition: form-data; name=\"file\"; filename=\"ignored;name.png\"\r\nContent-Type: application/octet-stream\r\n\r\n" +
  file +
  b"\r\n--test--\r\n"
}

///|
test "multipart binary payload retains NUL invalid UTF-8 and boundary-like bytes" {
  let bytes = b"\x00\xff\r\n--testX\r\n--test--X\r\nbytes\r\n"
  let upload = admin_multipart(upload_test_body(bytes), "test")
  assert_eq(upload.token, "token")
  assert_eq(upload.name, "月.png")
  assert_eq(upload.bytes, bytes)
  assert_eq(admin_multipart(upload_test_body(b""), "test").bytes, b"")
  assert_eq(
    admin_multipart_boundary("multipart/form-data; boundary=\"test\""),
    "test",
  )
}

///|
test "multipart rejects ambiguity unsupported fields and malformed framing" {
  let good = upload_test_body(b"file")
  for
    body in [
      good + b"epilogue",
      b"preamble" + good,
      upload_test_part("token", b"a") + good,
      upload_test_part("unknown", b"x") + good,
      upload_test_part("name", b"a") + b"--test--\r\n",
      good[:good.length() - 8].to_owned(),
      upload_test_part("token", b"\xff") +
      upload_test_part("name", b"a.png") +
      b"--test\r\nContent-Disposition: form-data; name=\"file\"; filename=\"x\"\r\n\r\nx\r\n--test--\r\n",
    ] {
    try admin_multipart(body, "test") catch {
      _ => ()
    } noraise {
      _ => fail("Bad multipart accepted")
    }
  }
  for
    header in [
      "form-data; name=\"file\"; filename=\"\"", "form-data; name=\"file\"; filename*=x",
      "form-data; name=\"name\"; filename=\"x\"",
    ] {
    try admin_part_name("Content-Disposition: " + header) catch {
      _ => ()
    } noraise {
      _ => fail("Bad disposition accepted")
    }
  }
  for
    boundary in [
      "",
      "bad boundary",
      "bad;boundary",
      "\"unclosed",
      "a".repeat(71),
    ] {
    try
      admin_multipart_boundary("multipart/form-data; boundary=" + boundary)
    catch {
      _ => ()
    } noraise {
      _ => fail("Bad boundary accepted")
    }
  }
}

///|
test "upload route alone accepts bounded multipart bodies" {
  let base = "POST /upload HTTP/1.1\r\nHost: 127.0.0.1:8080\r\nOrigin: http://127.0.0.1:8080\r\nContent-Type: multipart/form-data; boundary=test\r\nContent-Length: "
  assert_eq(
    admin_headers(base + "8388608\r\n\r\n", "127.0.0.1:8080").boundary,
    Some("test"),
  )
  for
    raw in [
      base + "8388609\r\n\r\n",
      base.replace_all(old="/upload", new="/save") + "1\r\n\r\n",
      base.replace_all(
        old="multipart/form-data; boundary=test",
        new="application/x-www-form-urlencoded",
      ) +
      "1\r\n\r\n",
    ] {
    try admin_headers(raw, "127.0.0.1:8080") catch {
      _ => ()
    } noraise {
      _ => fail("Bad upload route accepted")
    }
  }
}
