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

///|
test "media thumbnails escape filenames and exclude unsupported formats and size" {
  let item = media_item("月 &\".PNG", b"image")
  let html = admin_media_thumbnail(item)
  assert_true(
    html.contains("name=%E6%9C%88%20%26%22.PNG&amp;version=" + item.digest),
  )
  assert_true(html.contains("alt=\"Saved image: 月 &amp;&quot;.PNG\""))
  assert_true(html.contains("loading=\"lazy\""))
  assert_true(html.contains("rel=\"noopener noreferrer\""))
  assert_false(
    admin_media_thumbnail(media_item("a.svg", b"<svg/>")).contains("<img"),
  )
  assert_false(
    admin_media_thumbnail({
      source: "public/a.png",
      url: "a.png",
      bytes: 8388609,
      digest: item.digest,
      image: true,
    }).contains("<img"),
  )
  assert_true(
    decode_text(admin_response(200, ""), "headers").contains("img-src 'self'"),
  )
}
