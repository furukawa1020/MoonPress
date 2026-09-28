///|
fn index_heading_ids(outline : Array[HeadingInfo]) -> Map[String, Bool] {
  let ids : Map[String, Bool] = Map([])
  for heading in outline {
    ids[url_component(heading.id)] = true
  }
  ids
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
