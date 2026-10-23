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
