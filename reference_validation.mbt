///|
fn validate_reference_graph(
  graph : ReferenceGraph,
) -> Map[String, RouteInfo] raise {
  let routes : Map[String, RouteInfo] = Map([])
  let mut pages = 0
  for route in graph.routes {
    if !safe_output_name(route.name) ||
      routes.contains(route.name) ||
      !["page", "archive", "asset", "marker", "feed", "sitemap", "redirect"].contains(
        route.kind,
      ) {
      raise InvalidInput(
        "Invalid or duplicate reference graph route: " + route.name,
      )
    }
    if route.kind == "page" {
      pages += 1
    }
    routes[route.name] = route
  }
  if graph.pages != pages {
    raise InvalidInput("Reference graph page count does not match routes")
  }
  for route in graph.routes {
    if route.kind == "redirect" {
      match route.target {
        Some(target) if routes.contains(target) &&
          routes[target].kind != "redirect" => ()
        _ => raise InvalidInput("Invalid reference graph redirect target")
      }
    } else if route.target is Some(_) {
      raise InvalidInput("Unexpected reference graph route target")
    }
  }
  for edge in graph.references {
    if !routes.contains(edge.output) ||
      !routes.contains(edge.target) ||
      edge.source.is_empty() ||
      edge.url.is_empty() ||
      ![
        "markdown-link", "markdown-image", "template-href", "template-src", "redirect",
      ].contains(edge.kind) {
      raise InvalidInput("Invalid reference graph edge")
    }
    let origin = routes[edge.output]
    if edge.kind == "redirect" {
      if origin.kind != "redirect" ||
        origin.target != Some(edge.target) ||
        edge.fragment is Some(_) {
        raise InvalidInput(
          "Redirect reference does not match its route metadata",
        )
      }
    } else if edge.kind == "markdown-link" || edge.kind == "markdown-image" {
      if origin.kind != "page" || origin.source != Some(edge.source) {
        raise InvalidInput("Markdown reference must match its page source")
      }
    } else if origin.kind != "page" && origin.kind != "archive" {
      raise InvalidInput("Template references require a page or archive output")
    }
  }
  routes
}
