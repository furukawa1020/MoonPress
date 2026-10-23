///|
fn rest_response(result : RestResponse, head : Bool) -> Bytes {
  let bytes = @utf8.encode(result.value.stringify() + "\n")
  let status = match result.code {
    200 => "200 OK"
    201 => "201 Created"
    409 => "409 Conflict"
    400 => "400 Bad Request"
    401 => "401 Unauthorized"
    403 => "403 Forbidden"
    412 => "412 Precondition Failed"
    428 => "428 Precondition Required"
    404 => "404 Not Found"
    405 => "405 Method Not Allowed"
    _ => "500 Internal Server Error"
  }
  @utf8.encode(
    "HTTP/1.1 " +
    status +
    "\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: \{bytes.length()}\r\nConnection: close\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nX-Frame-Options: DENY\r\nReferrer-Policy: no-referrer\r\nContent-Security-Policy: default-src 'none'; frame-ancestors 'none'; base-uri 'none'\r\n" +
    (if result.code == 405 { "Allow: GET, HEAD\r\n" } else { "" }) +
    (if result.code == 401 {
      "WWW-Authenticate: Basic realm=\"MoonPress generated credentials\"\r\n"
    } else {
      ""
    }) +
    (match result.location {
      Some(path) => "Location: " + path + "\r\n"
      None => ""
    }) +
    (match result.etag {
      Some(digest) => "ETag: \"" + digest + "\"\r\n"
      None => ""
    }) +
    (match result.total {
      Some(total) => "X-WP-Total: \{total}\r\n"
      None => ""
    }) +
    (match result.pages {
      Some(pages) => "X-WP-TotalPages: \{pages}\r\n"
      None => ""
    }) +
    "\r\n",
  ) +
  (if head { b"" } else { bytes })
}

///|
fn rest_client(
  client : Int,
  host : String,
  input : String,
  base : String,
) -> Bytes {
  let mut head = false
  let mut selection : Array[String] = []
  let result = try {
    let (request, body) = admin_read_request(
      client,
      host,
      allow_head=true,
      rest=true,
      on_head=fn() { head = true },
    )
    head = request.verb == "HEAD"
    let (path, query) = rest_target(request.target)
    selection = rest_fields(query.get("_fields"))
    query.remove("_fields")
    if request.verb == "POST" ||
      (
        query.get("context") == Some("edit") &&
        path != "/wp-json/wp/v2/users/me"
      ) {
      try {
        if request.verb == "POST" && rest_is_collection(path) {
          rest_create(input, path, query, base, request.authorization, body)
        } else if request.verb != "POST" && rest_is_collection(path) {
          rest_edit_collection(input, path, query, base, request.authorization)
        } else {
          rest_edit(
            input,
            path,
            query,
            base,
            request.authorization,
            if request.verb == "POST" {
              Some(body)
            } else {
              None
            },
            request.if_match,
          )
        }
      } catch {
        _ => rest_error(500, "moonpress_edit_unavailable")
      }
    } else if request.verb != "GET" && !head {
      rest_error(405, "rest_no_route")
    } else {
      let principal = match request.authorization {
        Some(value) => {
          // Bad credentials and corrupt stores share a generic denial. No fallback.
          let user = try {
            let (login, secret) = rest_basic(value)
            authenticate_access(input, login, secret)
          } catch {
            _ => None
          }
          match user {
            Some(user) => Some(user)
            None =>
              return rest_response(rest_error(401, "rest_not_logged_in"), head)
          }
        }
        None => None
      }
      // Request grammar errors and unsupported parameters are returned as 400.
      // Storage failures must not reveal source names or record contents.
      rest_route(input, path, query, base, principal)
    }
  } catch {
    _ => rest_error(400, "moonpress_request_rejected")
  }
  let result = if result.code >= 200 &&
    result.code < 300 &&
    !selection.is_empty() {
    { ..result, value: rest_project(result.value, selection), }
  } else {
    result
  }
  if @utf8.encode(result.value.stringify()).length() > 16777216 {
    return rest_response(rest_error(500, "moonpress_response_limit"), head)
  }
  rest_response(result, head)
}

///|
pub fn serve_wordpress_rest(input : String, port : Int) -> Unit raise {
  if port < 1024 || port > 65535 {
    raise InvalidInput("REST port must be 1024–65535")
  }
  let content = open_authoring_subdirectory(input, "content")
  defer directory_close(content.fd)
  let host = "127.0.0.1:\{port}"
  let base = read_site_config(input).base_url.unwrap_or("http://" + host + "/")
  let server = admin_listen(port)
  if server < 0 {
    raise InvalidInput("Cannot bind REST to " + host)
  }
  defer admin_close(server)
  println(
    "MoonPress REST subset: http://" +
    host +
    "/wp-json/ (authenticated existing-article edits; Ctrl-C to stop)",
  )
  admin_flush()
  while true {
    let client = admin_accept(server)
    if client < 0 {
      raise InvalidInput("REST accept failed")
    }
    let bytes = rest_client(client, host, input, base)
    admin_send(client, bytes, bytes.length()) |> ignore
    admin_close(client)
  }
}
