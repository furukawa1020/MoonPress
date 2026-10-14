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
  let routes = validate_reference_graph(graph)
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
