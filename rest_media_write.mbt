///|
extern "C" fn native_root_matches(root : Int, child : Int) -> Int = "moonpress_root_matches_child"

///|
fn native_public_open(
  input : String,
  content : AuthoringDirectory,
) -> AuthoringDirectory raise {
  let root = open_authoring_directory(input)
  defer directory_close(root.fd)
  root.lock()
  if native_root_matches(root.fd, content.fd) != 1 {
    raise InvalidInput("Site root identity changed")
  }
  if root.kind("public") == 0 &&
    directory_prepare_private(root.fd, authoring_name("public")) < 0 {
    raise InvalidInput("Cannot prepare asset directory")
  }
  let public = open_authoring_subdirectory(input, "public")
  errdefer directory_close(public.fd)
  if native_media_same_site(content.fd, public.fd) != 1 {
    raise InvalidInput("Asset site identity changed")
  }
  public
}

///|
fn native_base64_digit(byte : Byte) -> Int {
  let n = byte.to_int()
  if n >= 65 && n <= 90 {
    n - 65
  } else if n >= 97 && n <= 122 {
    n - 71
  } else if n >= 48 && n <= 57 {
    n + 4
  } else if n == 43 {
    62
  } else if n == 47 {
    63
  } else {
    -1
  }
}

///|
fn native_base64(text : String) -> Bytes raise {
  let source = @utf8.encode(text)
  let length = source.length()
  if length == 0 || length > 8388608 || length % 4 != 0 {
    raise InvalidInput("Base64 size/length rejected")
  }
  let padding = if source[length - 1] == b'=' {
    if source[length - 2] == b'=' {
      2
    } else {
      1
    }
  } else {
    0
  }
  let size = length / 4 * 3 - padding
  if size > 6291456 {
    raise InvalidInput("Decoded upload exceeds 6 MiB")
  }
  let out : FixedArray[Byte] = FixedArray::make(size, 0)
  let mut offset = 0
  for i = 0; i < length; i = i + 4 {
    let a = native_base64_digit(source[i])
    let b = native_base64_digit(source[i + 1])
    let c = native_base64_digit(source[i + 2])
    let d = native_base64_digit(source[i + 3])
    let last = i + 4 == length
    if a < 0 ||
      b < 0 ||
      (c < 0 && !(last && padding == 2 && source[i + 2] == b'=')) ||
      (d < 0 && !(last && padding > 0 && source[i + 3] == b'=')) ||
      (last && padding == 2 && b % 16 != 0) ||
      (last && padding == 1 && c % 4 != 0) {
      raise InvalidInput("Noncanonical base64")
    }
    out[offset] = (a * 4 + b / 16).to_byte()
    offset += 1
    if c >= 0 {
      out[offset] = (b % 16 * 16 + c / 4).to_byte()
      offset += 1
    }
    if d >= 0 {
      out[offset] = (c % 4 * 64 + d).to_byte()
      offset += 1
    }
  }
  Bytes::from_array(out[:])
}

///|
fn native_media_upload(
  input : String,
  content : AuthoringDirectory,
  principal : AccessPrincipal,
  query : Map[String, String],
  base : String,
  body : Bytes,
) -> RestResponse raise {
  if !role_capabilities(principal.role).contains("upload_files") {
    return rest_error(403, "rest_cannot_upload")
  }
  if !query.is_empty() {
    return rest_error(400, "rest_invalid_param")
  }
  let (name, bytes) = try {
    let fields = strict_json_object(
      @json.parse(decode_text(body, "Upload")),
      ["name", "data"],
      "Upload",
    )
    let name = match fields.get("name") {
      Some(String(name)) => name
      _ => raise InvalidInput("Expected filename")
    }
    let data = match fields.get("data") {
      Some(String(data)) => data
      _ => raise InvalidInput("Expected base64")
    }
    require_media_destination(name)
    let bytes = native_base64(data)
    let mime = match raster_preview_mime(name) {
      Some(mime) => mime
      None => raise InvalidInput("Only raster upload supported")
    }
    if !media_preview_signature(mime, bytes) {
      raise InvalidInput("Image signature mismatch")
    }
    (name, bytes)
  } catch {
    _ => return rest_error(400, "rest_invalid_param")
  }
  let directory = native_public_open(input, content)
  defer directory_close(directory.fd)
  directory.lock()
  if directory.kind(name) != 0 {
    return rest_error(409, "moonpress_media_exists")
  }
  directory.write_new(name, bytes)
  {
    ..rest_ok(
      native_media_value(name, bytes, base),
      etag=Some(digest_bytes(bytes)),
      location=Some("/wp-json/moonpress/v1/media/" + url_component(name)),
    ),
    code: 201,
  }
}
