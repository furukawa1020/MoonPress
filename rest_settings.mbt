///|
fn native_settings_path(path : String) -> Bool {
  native_parts(path) == ["settings"]
}

///|
fn native_settings_read(
  input : String,
  content : AuthoringDirectory,
  principal : AccessPrincipal,
  query : Map[String, String],
) -> RestResponse raise {
  if !role_capabilities(principal.role).contains("manage_options") {
    return rest_error(403, "moonpress_cannot_manage_settings")
  }
  if !query.is_empty() {
    return rest_error(400, "rest_invalid_param")
  }
  let root = open_authoring_directory(input)
  defer directory_close(root.fd)
  root.lock()
  if native_root_matches(root.fd, content.fd) != 1 {
    raise InvalidInput("Site root identity changed")
  }
  let saved = read_settings_at(root)
  parse_site_config(saved.content) |> ignore
  rest_ok(
    {
      "settings": @json.parse(saved.content),
      "revision": saved.digest.unwrap_or("absent").to_json(),
      "exists": saved.exists.to_json(),
    },
    etag=Some(saved.digest.unwrap_or("absent")),
  )
}

///|
fn native_settings_save(
  input : String,
  content : AuthoringDirectory,
  principal : AccessPrincipal,
  query : Map[String, String],
  version : String?,
  body : Bytes,
) -> RestResponse raise {
  if !role_capabilities(principal.role).contains("manage_options") {
    return rest_error(403, "moonpress_cannot_manage_settings")
  }
  if !query.is_empty() {
    return rest_error(400, "rest_invalid_param")
  }
  let settings = try {
    let fields = strict_json_object(
      @json.parse(decode_text(body, "Settings")),
      ["settings"],
      "Settings",
    )
    let value = match fields.get("settings") {
      Some(Object(_) as value) => value
      _ => raise InvalidInput("Settings must be an object")
    }
    parse_site_config(value.stringify()) |> ignore
    value
  } catch {
    _ => return rest_error(400, "rest_invalid_param")
  }
  let root = open_authoring_directory(input)
  defer directory_close(root.fd)
  root.lock()
  if native_root_matches(root.fd, content.fd) != 1 {
    raise InvalidInput("Site root identity changed")
  }
  let current = read_settings_at(root)
  if rest_precondition(version, current.digest.unwrap_or("absent"))
    is Some(error) {
    return error
  }
  let unchanged = current.exists && @json.parse(current.content) == settings
  let saved = if unchanged {
    { digest: current.digest.unwrap(), changed: false, created: false, }
  } else {
    save_site_settings_at(
      input,
      root,
      current.digest.unwrap_or("absent"),
      settings.stringify() + "\n",
    )
  }
  rest_ok(
    {
      "settings": settings,
      "revision": saved.digest.to_json(),
      "exists": true.to_json(),
      "changed": saved.changed.to_json(),
    },
    etag=Some(saved.digest),
  )
}
