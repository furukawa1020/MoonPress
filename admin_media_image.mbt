///|
fn admin_media_image(input : String, request : AdminRequest) -> Bytes raise {
  if request.verb != "GET" || !request.target.has_prefix("/media-image?") {
    raise InvalidInput("Media image requires a versioned GET URL")
  }
  let fields = admin_form(request.target[13:].to_owned())
  if fields.length() != 2 ||
    !fields.contains("name") ||
    !fields.contains("version") {
    raise InvalidInput("Media image requires exactly name and version")
  }
  let preview = read_media_preview(
    input,
    admin_field(fields, "name"),
    expected=Some(admin_field(fields, "version")),
  )
  admin_image_response(preview)
}

///|
fn admin_image_response(preview : MediaPreview) -> Bytes {
  @utf8.encode(
    "HTTP/1.1 200 OK\r\nContent-Type: " +
    preview.mime +
    "\r\nContent-Length: \{preview.content.length()}\r\nConnection: close\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nX-Frame-Options: DENY\r\nCross-Origin-Resource-Policy: same-origin\r\nReferrer-Policy: no-referrer\r\nContent-Security-Policy: default-src 'none'; sandbox; frame-ancestors 'none'; base-uri 'none'\r\n\r\n",
  ) +
  preview.content
}
