///|
extern "C" fn admin_flush() -> Unit = "moonpress_admin_flush"

///|
fn admin_response(code : Int, html : String, language? : String = "") -> Bytes {
  let html = admin_render_language(html, language)
  let content_language = if html.has_prefix("<!doctype html><html lang=\"ja\">") {
    "ja"
  } else {
    "en"
  }
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
    "\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \{bytes.length()}\r\nContent-Language: " +
    content_language +
    "\r\nVary: Accept-Language, Cookie\r\nConnection: close\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nX-Frame-Options: DENY\r\nReferrer-Policy: same-origin\r\nContent-Security-Policy: default-src 'none'; img-src 'self'; font-src 'self'; style-src 'unsafe-inline'; form-action 'self'; frame-ancestors 'none'; base-uri 'none'\r\n\r\n",
  ) +
  bytes
}

///|
pub fn serve_admin(input : String, port : Int) -> Unit raise {
  if port < 1024 || port > 65534 {
    raise InvalidInput("Admin port must be 1024–65534")
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
  let preview_port = port + 1
  let preview_server = admin_listen(preview_port)
  if preview_server < 0 {
    raise InvalidInput(
      "Cannot bind preview to 127.0.0.1:\{preview_port}; choose another admin port pair",
    )
  }
  defer admin_close(preview_server)
  let host = "127.0.0.1:\{port}"
  println(
    "MoonPress admin: http://" + host + "/rooms (Ctrl-C to stop; no deployment)",
  )
  println(
    "MoonPress preview: http://127.0.0.1:\{preview_port}/ (build preview files first)",
  )
  admin_flush()
  while true {
    let selected = admin_wait_listener(server, preview_server)
    if selected < 0 {
      raise InvalidInput("Admin listener failed")
    }
    let client = admin_accept(
      if selected == 1 {
        preview_server
      } else {
        server
      },
    )
    if client < 0 {
      raise InvalidInput("Admin accept failed")
    }
    let response = if selected == 1 {
      preview_client(
        client,
        "127.0.0.1:\{preview_port}",
        input.trim_end(chars="/").to_owned() + "/.moonpress-preview",
      )
    } else {
      let mut language = ""
      try {
        let (request, body) = admin_read_request(client, host)
        language = request.language
        if request.target.has_prefix("/language/") {
          admin_language_response(request)
        } else if request.target.has_prefix("/assets/") {
          admin_ui_asset(request)
        } else if request.target == "/export-production" {
          admin_export(input, request, body, token)
        } else if request.target == "/media-image" ||
          request.target.has_prefix("/media-image?") {
          admin_media_image(input, request)
        } else {
          let (code, html) = admin_dispatch(input, request, body, token)
          let html = admin_preview_navigation(html, preview_port).replace_all(
            old="<main id=",
            new=admin_language_navigation(request.target) + "<main id=",
          )
          admin_response(code, html, language~)
        }
      } catch {
        error =>
          admin_response(
            400,
            admin_page(
              "Request rejected",
              "<p>" +
              escape_html(error.to_string()) +
              "</p>" +
              admin_recovery_links() +
              "<p><a href=\"/publish\">Check publication readiness</a> · <a href=\"/workflow#review\">Review production</a> · <a href=\"/\"><!--mp:ja-->記事へ戻る<!--mp:en-->Return to posts<!--mp:end--></a></p>",
            ),
            language~,
          )
      }
    }
    admin_send(client, response, response.length()) |> ignore
    admin_close(client)
  }
}

///|
extern "C" fn admin_wait_listener(admin : Int, preview : Int) -> Int = "moonpress_admin_wait_listener"

///|
fn admin_preview_navigation(html : String, port : Int) -> String {
  html.replace_all(
    old=" · Local administration</nav>",
    new=" · <a target=\"_blank\" rel=\"noopener noreferrer\" href=\"http://127.0.0.1:\{port}/\"><!--mp:ja-->生成したプレビューを開く<!--mp:en-->Open built preview<!--mp:end--></a> · Local administration</nav>",
  )
}
