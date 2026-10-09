///|
extern "C" fn admin_listen(port : Int) -> Int = "moonpress_admin_listen"

///|
extern "C" fn admin_accept(server : Int) -> Int = "moonpress_admin_accept"

///|
extern "C" fn admin_close(fd : Int) -> Unit = "moonpress_admin_close"

///|
#borrow(bytes)
extern "C" fn admin_recv(fd : Int, bytes : Bytes, length : Int) -> Int = "moonpress_admin_recv"

///|
#borrow(bytes)
extern "C" fn admin_send(fd : Int, bytes : Bytes, length : Int) -> Int = "moonpress_admin_send"

///|
#borrow(bytes)
extern "C" fn admin_random(bytes : Bytes) -> Int = "moonpress_admin_random"

///|
priv struct AdminRequest {
  verb : String
  target : String
  length : Int
  boundary : String?
}

///|
fn admin_headers(raw : String, host : String) -> AdminRequest raise {
  let lines = raw.split("\r\n").map(s => s.to_owned()).to_array()
  let start = lines[0].split(" ").map(s => s.to_owned()).to_array()
  if start.length() != 3 ||
    start[2] != "HTTP/1.1" ||
    (start[0] != "GET" && start[0] != "POST") {
    raise InvalidInput("Unsupported request line")
  }
  let headers : Map[String, String] = Map([])
  for i = 1; i < lines.length(); i = i + 1 {
    let line = lines[i]
    if line.is_empty() {
      continue
    }
    let (key, value) = match line.split_once(":") {
      Some((key, value)) =>
        (
          key.to_owned().to_lower(),
          value.to_owned().trim(chars=" \t").to_owned(),
        )
      None => raise InvalidInput("Invalid header")
    }
    if key.is_empty() ||
      !key.all(c => c.is_ascii_alphabetic() || c.is_ascii_digit() || c == '-') ||
      headers.contains(key) ||
      value.any(c => c.is_control()) {
      raise InvalidInput("Invalid or duplicate header")
    }
    headers[key] = value
  }
  if headers.get("host") != Some(host) {
    raise InvalidInput("Host rejected")
  }
  if headers.contains("transfer-encoding") ||
    headers.contains("content-encoding") ||
    headers.contains("expect") {
    raise InvalidInput("Unsupported request framing")
  }
  if headers.get("origin") is Some(origin) {
    if origin != "http://" + host {
      raise InvalidInput("Origin rejected")
    }
  }
  if headers.get("sec-fetch-site") is Some("cross-site") {
    raise InvalidInput("Cross-site request rejected")
  }
  let length_text = headers.get("content-length").unwrap_or("0")
  if length_text.is_empty() ||
    length_text.length() > 7 ||
    !length_text.all(c => c.is_ascii_digit()) {
    raise InvalidInput("Invalid content length")
  }
  let mut length = 0
  for c in length_text {
    length = length * 10 + c.to_int() - 48
  }
  let content_type = headers.get("content-type").unwrap_or("")
  let boundary = if start[0] == "POST" && start[1] == "/upload" {
    Some(admin_multipart_boundary(content_type))
  } else {
    None
  }
  let limit = if boundary is Some(_) { 8388608 } else { 262144 }
  if length > limit {
    raise InvalidInput("Request body exceeds route limit (\{limit} bytes)")
  }
  if start[0] == "POST" {
    if !headers.contains("content-length") ||
      headers.get("origin") != Some("http://" + host) ||
      (boundary is None && content_type != "application/x-www-form-urlencoded") {
      raise InvalidInput("POST requires same-origin form encoding")
    }
  } else if length != 0 {
    raise InvalidInput("GET body rejected")
  }
  { verb: start[0], target: start[1], length, boundary, }
}

///|
fn admin_read_request(fd : Int, host : String) -> (AdminRequest, Bytes) raise {
  let buffer = Bytes::make(4096, 0)
  let header = StringBuilder()
  let mut raw = ""
  let mut state = 0
  for i = 0; i < 16384; i = i + 1 {
    if admin_recv(fd, buffer, 1) != 1 {
      raise InvalidInput("Incomplete request or timeout")
    }
    let n = buffer[0].to_int()
    if n > 127 || n == 0 {
      raise InvalidInput("Non-ASCII header")
    }
    header.write_char(n.unsafe_to_char())
    state = if (state == 0 || state == 2) && n == 13 {
      state + 1
    } else if (state == 1 || state == 3) && n == 10 {
      state + 1
    } else if n == 13 {
      1
    } else {
      0
    }
    if state == 4 {
      raw = header.to_string()
      break
    }
  }
  if raw.is_empty() {
    raise InvalidInput("Headers too large (16 KiB limit)")
  }
  let request = admin_headers(raw, host)
  let body : FixedArray[Byte] = FixedArray::make(request.length, 0)
  let mut offset = 0
  while offset < request.length {
    let remaining = request.length - offset
    let n = admin_recv(
      fd,
      buffer,
      if remaining < 4096 {
        remaining
      } else {
        4096
      },
    )
    if n <= 0 {
      raise InvalidInput("Incomplete body or timeout")
    }
    for i = 0; i < n; i = i + 1 {
      body[offset + i] = buffer[i]
    }
    offset += n
  }
  (request, Bytes::from_array(body[:]))
}

///|
fn admin_decode(value : String) -> String raise {
  let bytes = @utf8.encode(value)
  let result : Array[Byte] = []
  let digits = "0123456789ABCDEF"
  let mut i = 0
  while i < bytes.length() {
    let n = bytes[i].to_int()
    if n == 37 {
      if i + 2 >= bytes.length() {
        raise InvalidInput("Invalid percent escape")
      }
      let a = bytes[i + 1].to_int().unsafe_to_char().to_string().to_upper()
      let b = bytes[i + 2].to_int().unsafe_to_char().to_string().to_upper()
      let high = digits.find(a).unwrap_or(-1)
      let low = digits.find(b).unwrap_or(-1)
      if high < 0 || low < 0 {
        raise InvalidInput("Invalid percent escape")
      }
      result.push((high * 16 + low).to_byte())
      i += 3
    } else {
      result.push(if n == 43 { b' ' } else { bytes[i] })
      i += 1
    }
  }
  decode_text(Bytes::from_array(result), "form value")
}

///|
fn admin_form(body : String) -> Map[String, String] raise {
  let fields : Map[String, String] = Map([])
  if body.is_empty() {
    return fields
  }
  for field in body.split("&") {
    let (key, value) = match field.split_once("=") {
      Some((key, value)) =>
        (admin_decode(key.to_owned()), admin_decode(value.to_owned()))
      None => raise InvalidInput("Invalid form field")
    }
    if fields.contains(key) {
      raise InvalidInput("Duplicate form field")
    }
    fields[key] = value
  }
  fields
}

///|
fn admin_field(fields : Map[String, String], name : String) -> String raise {
  match fields.get(name) {
    Some(value) => value
    None => raise InvalidInput("Missing field: " + name)
  }
}
