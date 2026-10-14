///|
pub(all) struct RouteReferences {
  route : RouteInfo
  include_drafts : Bool
  incoming : Array[ReferenceEdge]
  outgoing : Array[ReferenceEdge]
  scope : String
} derive(ToJson)

///|
pub extend RouteReferences with ToJson::{to_json}

///|
pub fn query_references(
  graph : ReferenceGraph,
  name : String,
) -> RouteReferences raise {
  if !safe_output_name(name) {
    raise InvalidInput("Reference query requires an exact flat output filename")
  }
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
        Some(target) if routes.contains(target) => ()
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
    } else if origin.kind == "redirect" {
      raise InvalidInput(
        "Redirect output cannot consume Markdown or template references",
      )
    }
  }
  let route = match routes.get(name) {
    Some(route) => route
    None =>
      raise InvalidInput("Unknown output filename in reference graph: " + name)
  }
  let edges = sorted_reference_edges(graph.references)
  {
    route,
    include_drafts: graph.include_drafts,
    incoming: edges.filter(edge => edge.target == name),
    outgoing: edges.filter(edge => edge.output == name),
    scope: reference_scope(),
  }
}

///|
pub fn inspect_backlinks(
  input : String,
  name : String,
  include_drafts? : Bool = false,
) -> RouteReferences raise {
  query_references(inspect_references(input, include_drafts~), name)
}
