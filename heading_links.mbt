///|
fn index_heading_targets(
  outputs : Array[String],
  pages : Array[Page],
) -> Map[String, Map[String, Bool]] {
  let targets : Map[String, Map[String, Bool]] = Map([])
  // Collections have no generated heading IDs, but are still HTML destinations.
  for name in outputs {
    if name.has_suffix(".html") {
      targets[url_component(name)] = Map([])
    }
  }
  for page in pages {
    let ids : Map[String, Bool] = Map([])
    for heading in headings(page.document.body) {
      ids[url_component(heading.id)] = true
    }
    targets[url_component(page.output)] = ids
  }
  targets
}

///|
fn validate_heading_links(
  links : Array[String],
  targets : Map[String, Map[String, Bool]],
  current : String,
  base_path : String,
  source : String,
) -> Unit raise {
  // Route/scheme validation runs first; this pass checks only generated IDs.
  for href in links {
    if url_scheme(href) is Some(_) {
      continue
    }
    let fragment = match href.split_once("#") {
      None => continue
      Some((_, fragment)) => fragment.to_owned()
    }
    let route = local_route(href, base_path, source).unwrap_or(
      url_component(current),
    )
    let ids = match targets.get(route) {
      None => continue // Asset fragments (SVG, PDF, etc.) have other semantics.
      Some(ids) => ids
    }
    let fragment = normalized_url_path(fragment) catch {
      _ => raise InvalidInput(source + ": invalid fragment escape: " + href)
    }
    if fragment.has_prefix("mp-") && !ids.contains(fragment) {
      raise InvalidInput(source + ": broken heading link: " + href)
    }
  }
}
