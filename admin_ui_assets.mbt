///|
fn admin_ui_asset(request : AdminRequest) -> Bytes raise {
  if request.verb != "GET" {
    raise InvalidInput("UI assets require GET")
  }
  let (mime, content) = match request.target {
    "/assets/logo.jpg" => ("image/jpeg", admin_logo_data)
    "/assets/font.woff" => ("font/woff", admin_font_data)
    "/assets/rooms.webp" => ("image/webp", admin_room_art_data)
    _ =>
      return admin_response(
        404,
        admin_page("Not found", "<p>Unknown UI asset.</p>"),
        language=request.language,
      )
  }
  @utf8.encode(
    "HTTP/1.1 200 OK\r\nContent-Type: " +
    mime +
    "\r\nContent-Length: \{content.length()}\r\nConnection: close\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nCross-Origin-Resource-Policy: same-origin\r\nContent-Security-Policy: default-src 'none'; sandbox\r\n\r\n",
  ) +
  content
}
