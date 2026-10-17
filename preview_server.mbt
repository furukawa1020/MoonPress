///|
fn preview_name(target : String) -> String raise {
  let path = target.split("?").to_array()[0].to_owned()
  if !path.has_prefix("/") {
    raise InvalidInput("Expected preview path")
  }
  if path == "/" {
    return "index.html"
  }
  let name = admin_decode(path[1:].to_owned().replace_all(old="+", new="%2B"))
  if !safe_output_name(name) || name.has_prefix(".") {
    raise InvalidInput("Invalid preview filename")
  }
  name
}

///|
fn preview_mime(name : String) -> String {
  let name = name.to_lower()
  if name.has_suffix(".html") {
    "text/html; charset=utf-8"
  } else if name.has_suffix(".css") {
    "text/css; charset=utf-8"
  } else if name.has_suffix(".png") {
    "image/png"
  } else if name.has_suffix(".jpg") || name.has_suffix(".jpeg") {
    "image/jpeg"
  } else if name.has_suffix(".gif") {
    "image/gif"
  } else if name.has_suffix(".webp") {
    "image/webp"
  } else if name.has_suffix(".avif") {
    "image/avif"
  } else if name.has_suffix(".svg") {
    "image/svg+xml"
  } else if name.has_suffix(".ico") {
    "image/x-icon"
  } else if name.has_suffix(".woff2") {
    "font/woff2"
  } else if name.has_suffix(".ttf") {
    "font/ttf"
  } else if name.has_suffix(".otf") {
    "font/otf"
  } else if name.has_suffix(".woff") {
    "font/woff"
  } else if name.has_suffix(".xml") {
    "application/xml; charset=utf-8"
  } else if name.has_suffix(".txt") {
    "text/plain; charset=utf-8"
  } else {
    "application/octet-stream"
  }
}

///|
fn preview_response(
  code : Int,
  mime : String,
  bytes : Bytes,
  head? : Bool = false,
) -> Bytes {
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
    "\r\nContent-Type: " +
    mime +
    "\r\nContent-Length: \{bytes.length()}\r\nConnection: close\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nX-Frame-Options: DENY\r\nReferrer-Policy: no-referrer\r\nContent-Security-Policy: default-src 'none'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; font-src 'self'; form-action 'none'; frame-ancestors 'none'; base-uri 'none'\r\n" +
    (if mime == "application/octet-stream" {
      "Content-Disposition: attachment\r\n"
    } else {
      ""
    }) +
    "\r\n",
  ) +
  (if head { b"" } else { bytes })
}

///|
fn preview_file(
  output : String,
  target : String,
  head? : Bool = false,
) -> Bytes raise {
  let name = preview_name(target)
  let lock = lock_output(output, shared=true)
  defer native_unlock_output(lock)
  let directory = open_authoring_directory(output)
  defer directory_close(directory.fd)
  let manifest = preview_manifest(directory)
  for artifact in manifest.artifacts {
    if artifact.name == name {
      let bytes = directory.read(name)
      if digest_bytes(bytes) != artifact.digest {
        raise InvalidInput("Preview output changed; rebuild before viewing")
      }
      return preview_response(200, preview_mime(name), bytes, head~)
    }
  }
  preview_response(
    404,
    "text/plain; charset=utf-8",
    b"No generated page at this URL. Build the saved-site preview first.\n",
    head~,
  )
}

///|
fn preview_client(client : Int, host : String, output : String) -> Bytes {
  let mut head = false
  try {
    let (request, _) = admin_read_request(client, host, allow_head=true)
    head = request.verb == "HEAD"
    if request.verb != "GET" && !head {
      raise InvalidInput("Preview is read-only")
    }
    preview_file(output, request.target, head~)
  } catch {
    _ =>
      preview_response(
        400,
        "text/plain; charset=utf-8",
        b"Preview unavailable or request rejected. Build preview files, then reload.\n",
        head~,
      )
  }
}

///|
pub fn serve_preview(output : String, port : Int) -> Unit raise {
  if port < 1024 || port > 65535 {
    raise InvalidInput("Preview port must be 1024–65535")
  }
  let directory = open_authoring_directory(output)
  defer directory_close(directory.fd)
  preview_manifest(directory) |> ignore
  let server = admin_listen(port)
  if server < 0 {
    raise InvalidInput("Cannot bind preview to 127.0.0.1:\{port}")
  }
  defer admin_close(server)
  let host = "127.0.0.1:\{port}"
  println("MoonPress preview: http://" + host + "/ (read-only; Ctrl-C to stop)")
  admin_flush()
  while true {
    let client = admin_accept(server)
    if client < 0 {
      raise InvalidInput("Preview accept failed")
    }
    let response = preview_client(client, host, output)
    admin_send(client, response, response.length()) |> ignore
    admin_close(client)
  }
}

///|
fn preview_manifest(directory : AuthoringDirectory) -> Manifest raise {
  let file = directory_read(directory.fd, b".moonpress.json\x00")
  if io_is_null(file) != 0 {
    raise io_failure("preview manifest open", directory.path)
  }
  parse_manifest(
    decode_text(read_opened_file(file, "preview manifest"), "preview manifest"),
  )
}
