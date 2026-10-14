///|
pub(all) struct RouteReferenceCount {
  route : RouteInfo
  incoming : Int
  outgoing : Int
  self_references : Int
  referring_outputs : Int
} derive(ToJson)

///|
pub extend RouteReferenceCount with ToJson::{to_json}

///|
pub(all) struct ReferenceSummary {
  pages : Int
  include_drafts : Bool
  edges : Int
  routes : Array[RouteReferenceCount]
  scope : String
} derive(ToJson)

///|
pub extend ReferenceSummary with ToJson::{to_json}

///|
pub fn summarize_references(graph : ReferenceGraph) -> ReferenceSummary raise {
  validate_reference_graph(graph) |> ignore
  let edges = sorted_reference_edges(graph.references)
  let incoming : Map[String, Int] = Map([])
  let outgoing : Map[String, Int] = Map([])
  let self_edges : Map[String, Int] = Map([])
  let referrers : Map[String, Map[String, Bool]] = Map([])
  for edge in edges {
    incoming[edge.target] = incoming.get(edge.target).unwrap_or(0) + 1
    outgoing[edge.output] = outgoing.get(edge.output).unwrap_or(0) + 1
    if edge.output == edge.target {
      self_edges[edge.target] = self_edges.get(edge.target).unwrap_or(0) + 1
    } else {
      let names = match referrers.get(edge.target) {
        Some(names) => names
        None => {
          let names : Map[String, Bool] = Map([])
          referrers[edge.target] = names
          names
        }
      }
      names[edge.output] = true
    }
  }
  let routes = sorted_routes(graph.routes).map(route => {
    let referring_outputs = match referrers.get(route.name) {
      Some(names) => names.length()
      None => 0
    }
    {
      route,
      incoming: incoming.get(route.name).unwrap_or(0),
      outgoing: outgoing.get(route.name).unwrap_or(0),
      self_references: self_edges.get(route.name).unwrap_or(0),
      referring_outputs,
    }
  })
  {
    pages: graph.pages,
    include_drafts: graph.include_drafts,
    edges: edges.length(),
    routes,
    scope: reference_scope(),
  }
}

///|
pub fn inspect_reference_summary(
  input : String,
  include_drafts? : Bool = false,
) -> ReferenceSummary raise {
  summarize_references(inspect_references(input, include_drafts~))
}
