///|
priv struct WpMedia {
  id : Int
  name : String
  bytes : Int
  mime : String
}

///|
fn wp_media_id(name : String) -> Int {
  rest_term_id("media", name)
}

///|
fn wp_media_validate_ids(rows : Array[WpMedia]) -> Unit raise {
  let used : Map[Int, Bool] = Map([])
  for row in rows {
    if used.contains(row.id) {
      raise InvalidInput("Public media identity collision")
    }
    used[row.id] = true
  }
}

///|
fn wp_media_snapshot(input : String) -> Array[WpMedia] raise {
  let content = open_authoring_subdirectory(input, "content")
  defer directory_close(content.fd)
  content.lock()
  if path_kind(input + "/public") == 0 {
    return []
  }
  let public = native_public_open(input, content, create=false)
  defer directory_close(public.fd)
  public.lock()
  let names = public.names()
  if names.length() > 4096 {
    raise InvalidInput("Public media entry limit")
  }
  names.sort()
  let rows : Array[WpMedia] = []
  let mut total = 0
  for name in names {
    require_media_destination(name)
    let bytes = public.read(name, max_bytes=8388608)
    total += bytes.length()
    if total > 67108864 {
      raise InvalidInput("Public media byte limit")
    }
    rows.push({
      id: wp_media_id(name),
      name,
      bytes: bytes.length(),
      mime: native_media_mime(name, bytes),
    })
  }
  wp_media_validate_ids(rows)
  rows
}
