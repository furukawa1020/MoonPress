///|
priv struct AdminUpload {
  token : String
  name : String
  bytes : Bytes
}

///|
fn admin_multipart_boundary(content_type : String) -> String raise {
  let prefix = "multipart/form-data; boundary="
  if !content_type.has_prefix(prefix) {
    raise InvalidInput("Upload requires multipart/form-data")
  }
  let mut boundary = content_type[prefix.length():].to_owned()
  if boundary.has_prefix("\"") &&
    boundary.has_suffix("\"") &&
    boundary.length() >= 2 {
    boundary = boundary[1:boundary.length() - 1].to_owned()
  }
  if boundary.is_empty() ||
    boundary.length() > 70 ||
    !boundary.all(c => {
      c.is_ascii_alphabetic() || c.is_ascii_digit() || c == '-' || c == '_'
    }) {
    raise InvalidInput("Unsupported multipart boundary")
  }
  boundary
}

///|
fn admin_part_name(raw : String) -> String raise {
  let headers : Map[String, String] = Map([])
  for line in raw.split("\r\n") {
    let (key, value) = match line.split_once(":") {
      Some((key, value)) =>
        (key.to_owned().to_lower(), value.trim(chars=" ").to_owned())
      None => raise InvalidInput("Invalid multipart header")
    }
    if (key != "content-disposition" && key != "content-type") ||
      headers.contains(key) ||
      value.any(c => c.is_control()) {
      raise InvalidInput("Unsupported or duplicate multipart header")
    }
    headers[key] = value
  }
  let disposition = admin_field(headers, "content-disposition")
  for name in ["token", "name"] {
    if disposition == "form-data; name=\"" + name + "\"" &&
      headers.length() == 1 {
      return name
    }
  }
  let prefix = "form-data; name=\"file\"; filename=\""
  if disposition.has_prefix(prefix) && disposition.has_suffix("\"") {
    let filename = disposition[prefix.length():disposition.length() - 1]
    if !filename.is_empty() && !filename.contains("\"") {
      return "file"
    }
  }
  raise InvalidInput("Unsupported multipart field disposition")
}

///|
fn admin_boundary_at(body : Bytes, start : Int, marker : Bytes) -> Int raise {
  let mut offset = start
  while offset < body.length() {
    let found = match body[offset:].find(marker[:]) {
      Some(found) => offset + found
      None => raise InvalidInput("Missing multipart closing boundary")
    }
    let suffix = found + marker.length()
    if body[suffix:].has_prefix(b"\r\n") {
      return found
    }
    if body[suffix:].has_prefix(b"--") &&
      (suffix + 2 == body.length() || body[suffix + 2:].has_prefix(b"\r\n")) {
      return found
    }
    offset = found + 1
  }
  raise InvalidInput("Missing multipart closing boundary")
}

///|
fn admin_multipart(body : Bytes, boundary : String) -> AdminUpload raise {
  if body.length() > 8388608 {
    raise InvalidInput("Upload request exceeds 8 MiB")
  }
  let opening = @utf8.encode("--" + boundary + "\r\n")
  let marker = @utf8.encode("\r\n--" + boundary)
  if !body[:].has_prefix(opening[:]) {
    raise InvalidInput("Invalid multipart opening")
  }
  let parts : Map[String, Bytes] = Map([])
  let mut offset = opening.length()
  while true {
    if parts.length() >= 3 {
      raise InvalidInput("Too many upload fields")
    }
    let header_size = match body[offset:].find(b"\r\n\r\n") {
      Some(size) if size <= 4096 => size
      _ => raise InvalidInput("Invalid or oversized multipart headers")
    }
    let name = admin_part_name(
      decode_text(
        body[offset:offset + header_size].to_owned(),
        "multipart headers",
      ),
    )
    if parts.contains(name) {
      raise InvalidInput("Duplicate upload field")
    }
    let start = offset + header_size + 4
    let end = admin_boundary_at(body, start, marker)
    if (name == "token" && end - start > 256) ||
      (name == "name" && end - start > 1024) {
      raise InvalidInput("Upload text field too large")
    }
    parts[name] = body[start:end].to_owned()
    offset = end + marker.length()
    if body[offset:].has_prefix(b"--") {
      offset += 2
      if offset != body.length() &&
        !(offset + 2 == body.length() && body[offset:].has_prefix(b"\r\n")) {
        raise InvalidInput("Multipart epilogue rejected")
      }
      break
    }
    offset += 2
  }
  if parts.length() != 3 {
    raise InvalidInput("Upload requires token, name and file")
  }
  {
    token: decode_text(parts["token"], "upload token"),
    name: decode_text(parts["name"], "upload name"),
    bytes: parts["file"],
  }
}

///|
fn admin_upload_form(token : String, name : String) -> String {
  "<h2>Upload a file</h2><form method=\"post\" action=\"/upload\" enctype=\"multipart/form-data\">" +
  admin_hidden("token", token) +
  "<p>Select one image or attachment. The complete request must fit within 8 MiB. Use Prepare media storage on the Media screen if needed. Existing names are never overwritten.</p><label>Destination filename<input name=\"name\" required value=\"" +
  escape_html(name) +
  "\"></label><label>File<input type=\"file\" name=\"file\" required></label><button>Upload media</button></form>"
}

///|
fn admin_dispatch(
  input : String,
  request : AdminRequest,
  body : Bytes,
  token : String,
) -> (Int, String) raise {
  if request.boundary is Some(boundary) {
    let upload = admin_multipart(body, boundary)
    if upload.token != token {
      raise InvalidInput("Form token rejected; reload the page")
    }
    try {
      let item = store_media(input, upload.name, upload.bytes)
      (
        200,
        admin_page(
          "Media uploaded",
          "<p>Uploaded " +
          escape_html(item.source) +
          " (\{item.bytes} bytes). No deployment performed.</p><label>Markdown snippet<textarea readonly rows=\"2\" style=\"min-height:4rem\">\n" +
          escape_html(media_snippet(item)) +
          "</textarea></label><p><a href=\"/media\">Return to media</a></p>",
        ),
      )
    } catch {
      error =>
        (
          400,
          admin_page(
            "Could not upload media",
            "<p class=\"notice\">" +
            escape_html(error.to_string()) +
            "</p><p>The filename is retained. Select the file again before retrying.</p>" +
            admin_upload_form(token, upload.name),
          ),
        )
    }
  } else {
    admin_route(input, request, decode_text(body, "form body"), token)
  }
}
