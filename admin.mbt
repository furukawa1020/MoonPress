///|
extern "C" fn admin_flush() -> Unit = "moonpress_admin_flush"

///|
fn admin_response(code : Int, html : String) -> Bytes {
  let bytes = @utf8.encode(html)
  let status = if code == 200 {
    "200 OK"
  } else if code == 404 {
    "404 Not Found"
  } else {
    "400 Bad Request"
  }
  @utf8.encode(
    "HTTP/1.1 " +
    status +
    "\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \{bytes.length()}\r\nConnection: close\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nX-Frame-Options: DENY\r\nReferrer-Policy: no-referrer\r\nContent-Security-Policy: default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; frame-ancestors 'none'; base-uri 'none'\r\n\r\n",
  ) +
  bytes
}

///|
pub fn serve_admin(input : String, port : Int) -> Unit raise {
  if port < 1024 || port > 65535 {
    raise InvalidInput("Admin port must be 1024–65535")
  }
  require_input_kind(input, 2)
  require_input_kind(input + "/content", 2)
  let random = Bytes::make(32, 0)
  if admin_random(random) != 0 {
    raise InvalidInput("Cannot obtain admin form token")
  }
  let token = @crypto.bytes_to_hex_string(random)
  let server = admin_listen(port)
  if server < 0 {
    raise InvalidInput("Cannot bind admin to 127.0.0.1:\{port}")
  }
  defer admin_close(server)
  let host = "127.0.0.1:\{port}"
  println(
    "MoonPress admin: http://" + host + "/ (Ctrl-C to stop; no deployment)",
  )
  admin_flush()
  while true {
    let client = admin_accept(server)
    if client < 0 {
      raise InvalidInput("Admin accept failed")
    }
    let response = try {
      let (request, body) = admin_read_request(client, host)
      let (code, html) = admin_dispatch(input, request, body, token)
      admin_response(code, html)
    } catch {
      error =>
        admin_response(
          400,
          admin_page(
            "Request rejected",
            "<p>" +
            escape_html(error.to_string()) +
            "</p><p><a href=\"/\">Return to posts</a></p>",
          ),
        )
    }
    admin_send(client, response, response.length()) |> ignore
    admin_close(client)
  }
}
