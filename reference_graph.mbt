///|
pub(all) struct ReferenceEdge {
  source : String
  output : String
  kind : String
  url : String
  target : String
  fragment : String?
} derive(Eq, ToJson)

///|
pub extend ReferenceEdge with Eq::{equal, not_equal}

///|
pub extend ReferenceEdge with ToJson::{to_json}

///|
pub(all) struct ReferenceGraph {
  pages : Int
  include_drafts : Bool
  routes : Array[RouteInfo]
  references : Array[ReferenceEdge]
  scope : String
} derive(ToJson)

///|
pub extend ReferenceGraph with ToJson::{to_json}

///|
fn reference_scope() -> String {
  "Authored local Markdown links/images, selected template href/src attributes per consuming output, and configured redirects to resolved targets. Excludes external URLs, generated navigation/TOC/feed/sitemap links, CSS URLs and unsupported HTML. This is not the rebuild dependency graph or proof that deletion is safe."
}

///|
fn append_reference_edges(
  edges : Array[ReferenceEdge],
  urls : Array[String],
  source : String,
  output : String,
  kind : String,
  routes : Map[String, String],
  base_path : String,
) -> Unit raise {
  for url in urls {
    if url_scheme(url) is Some(_) {
      continue
    }
    let key = local_route(url, base_path, source).unwrap_or(
      url_component(output),
    )
    let target = match routes.get(key) {
      Some(name) => name
      None => raise InvalidInput(source + ": unknown reference target: " + url)
    }
    let fragment = match url.split_once("#") {
      None => None
      Some((_, value)) => {
        // Asset fragment grammars are opaque to the compiler. Preserve invalid
        // percent escapes there rather than tightening existing validation.
        let raw = value.to_owned()
        Some(normalized_url_path(raw) catch { _ => raw })
      }
    }
    edges.push({ source, output, kind, url, target, fragment, })
  }
}

///|
fn sorted_reference_edges(edges : Array[ReferenceEdge]) -> Array[ReferenceEdge] {
  let seen : Map[String, Bool] = Map([])
  let result : Array[ReferenceEdge] = []
  for edge in edges {
    let key = edge.to_json().stringify()
    if !seen.contains(key) {
      seen[key] = true
      result.push(edge)
    }
  }
  result.sort_by((a, b) => {
    a.to_json().stringify().compare(b.to_json().stringify())
  })
  result
}

///|
pub fn inspect_references(
  input : String,
  include_drafts? : Bool = false,
) -> ReferenceGraph raise {
  let plan = plan_site(input, Map([]), None, include_drafts~)
  {
    pages: plan.report.pages,
    include_drafts,
    routes: sorted_routes(plan.routes),
    references: plan.references,
    scope: reference_scope(),
  }
}
