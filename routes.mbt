///|
pub(all) struct RouteInfo {
  name : String
  kind : String
  source : String?
  target : String?
} derive(ToJson)

///|
pub extend RouteInfo with ToJson::{to_json}

///|
pub(all) struct RouteInventory {
  pages : Int
  include_drafts : Bool
  routes : Array[RouteInfo]
} derive(ToJson)

///|
pub extend RouteInventory with ToJson::{to_json}

///|
fn sorted_routes(routes : Array[RouteInfo]) -> Array[RouteInfo] {
  let result = routes.map(route => route)
  result.sort_by((a, b) => a.name.compare(b.name))
  result
}

///|
pub fn inspect_routes(
  input : String,
  include_drafts? : Bool = false,
) -> RouteInventory raise {
  let plan = plan_site(input, Map([]), None, include_drafts~)
  {
    pages: plan.report.pages,
    include_drafts,
    routes: sorted_routes(plan.routes),
  }
}
