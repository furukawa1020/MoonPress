///|
test "media image response preserves binary bytes with restrictive policy" {
  let bytes = b"\x89PNG\r\n\x1a\n"
  let response = admin_image_response({
    item: media_item("a.png", bytes),
    mime: "image/png",
    content: bytes,
  })
  let prefix = @utf8.encode(
    "HTTP/1.1 200 OK\r\nContent-Type: image/png\r\nContent-Length: 8\r\n",
  )
  assert_true(preview_bytes_at(response, 0, prefix))
  assert_true(
    preview_bytes_at(response, response.length() - bytes.length(), bytes),
  )
  let header = decode_text(
    admin_image_response({
      item: media_item("a.png", b""),
      mime: "image/png",
      content: b"",
    }),
    "headers",
  )
  assert_true(header.contains("Cross-Origin-Resource-Policy: same-origin"))
  assert_true(header.contains("default-src 'none'; sandbox"))
  assert_true(header.contains("Cache-Control: no-store"))
}
