///|
fn validate_web_origin(origin : String) -> Unit raise {
  guard origin.has_prefix("https://") else {
    raise InvalidInput("Web administration needs an HTTPS origin")
  }
  let authority = origin[8:].to_owned()
  let (host, port) = match authority.split_once(":") {
    Some((host, port)) => (host.to_owned(), Some(port.to_owned()))
    None => (authority, None)
  }
  if host.length() > 253 ||
    !host
    .split(".")
    .all(label => {
      !label.is_empty() &&
      label.length() <= 63 &&
      !label.has_prefix("-") &&
      !label.has_suffix("-") &&
      label.all(c => c.is_ascii_alphabetic() || c.is_ascii_digit() || c == '-')
    }) {
    raise InvalidInput(
      "Web administration origin must have a DNS name or IPv4 address",
    )
  }
  if port is Some(port) {
    if port.is_empty() ||
      port.length() > 5 ||
      !port.all(c => c.is_ascii_digit()) ||
      port.has_prefix("0") ||
      port == "443" ||
      (port.length() == 5 && port > "65535") {
      raise InvalidInput(
        "Web administration origin has an invalid or default port",
      )
    }
  }
}

///|
fn web_output(input : String, request : AdminRequest) -> Bytes {
  let head = request.verb == "HEAD"
  if request.verb != "GET" && !head {
    return preview_response(
      400, "text/plain; charset=utf-8", b"Read-only output.\n",
    )
  }
  let production = request.target.has_prefix("/site/")
  let prefix_length = if production { 5 } else { 8 }
  let output = if production {
    admin_production_output(input)
  } else {
    input.trim_end(chars="/").to_owned() + "/.moonpress-preview"
  }
  try {
    if path_kind(output) == 0 {
      return preview_response(
        404,
        "text/plain; charset=utf-8",
        b"Build the site from MoonPress first.\n",
        head~,
      )
    }
    preview_file(
      output,
      request.target[prefix_length:].to_owned(),
      head~,
      if_none_match=request.if_none_match,
      web=true,
      production~,
    )
  } catch {
    _ =>
      preview_response(
        404,
        "text/plain; charset=utf-8",
        b"Page unavailable.\n",
        head~,
      )
  }
}
