///|
pub(all) struct Redirect {
  name : String
  target : String
} derive(Eq, ToJson)

///|
pub extend Redirect with Eq::{equal, not_equal}

///|
pub extend Redirect with ToJson::{to_json}

///|
fn redirect_path(name : String) -> Bool {
  safe_output_name(name) && name.has_suffix(".html") && name.length() > 5
}

///|
pub fn resolve_redirects(
  redirects : Array[Redirect],
  outputs : Array[String],
) -> Array[Redirect] raise {
  let routes : Map[String, Bool] = Map([])
  for name in outputs {
    if !safe_output_name(name) {
      raise InvalidInput("Invalid planned output: " + name)
    }
    if routes.contains(name) {
      raise InvalidInput("Output collision: " + name)
    }
    routes[name] = true
  }
  let mappings : Map[String, String] = Map([])
  for redirect in redirects {
    if !redirect_path(redirect.name) || !redirect_path(redirect.target) {
      raise InvalidInput("Redirect paths must be safe flat .html filenames")
    }
    if routes.contains(redirect.name) || mappings.contains(redirect.name) {
      raise InvalidInput("Redirect output collision: " + redirect.name)
    }
    mappings[redirect.name] = redirect.target
  }
  let result : Array[Redirect] = []
  let resolved : Map[String, String] = Map([])
  for redirect in redirects {
    let visited : Map[String, Bool] = Map([])
    let chain : Array[String] = []
    let mut target = redirect.name
    while mappings.get(target) is Some(next) {
      if resolved.get(target) is Some(terminal) {
        target = terminal
        break
      }
      if visited.contains(target) {
        raise InvalidInput("Redirect cycle: " + redirect.name)
      }
      visited[target] = true
      chain.push(target)
      target = next
    }
    if !routes.contains(target) {
      raise InvalidInput(
        "Redirect target is not a planned HTML output: " + target,
      )
    }
    for name in chain {
      resolved[name] = target
    }
    result.push({ name: redirect.name, target, })
  }
  result.sort_by((a, b) => a.name.compare(b.name))
  result
}

///|
pub fn render_redirect(
  target : String,
  base_url? : String? = None,
) -> String raise {
  if !redirect_path(target) {
    raise InvalidInput("Redirect target must be a safe flat .html filename")
  }
  let href = escape_html(url_component(target))
  let canonical = match base_url {
    None => ""
    Some(url) =>
      "<link rel=\"canonical\" href=\"" +
      escape_html(normalize_base_url(url) + url_component(target)) +
      "\">\n"
  }
  "<!doctype html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n<meta name=\"robots\" content=\"noindex\">\n<meta http-equiv=\"refresh\" content=\"0; url=" +
  href +
  "\">\n" +
  canonical +
  "<title>Page moved</title>\n</head>\n<body><p>This page has moved to <a href=\"" +
  href +
  "\">" +
  escape_html(target) +
  "</a>.</p></body>\n</html>\n"
}

///|
fn parse_redirect_config(value : Json?) -> Array[Redirect] raise {
  let fields = match value {
    None => return []
    Some(Object(fields)) => fields
    _ => raise InvalidInput("site.json: redirects must be an object")
  }
  let result : Array[Redirect] = []
  for name, value in fields {
    let target = match value {
      String(target) if redirect_path(name) && redirect_path(target) => target
      _ =>
        raise InvalidInput(
          "site.json: redirects require safe flat .html names and string targets",
        )
    }
    result.push({ name, target, })
  }
  result.sort_by((a, b) => a.name.compare(b.name))
  result
}
