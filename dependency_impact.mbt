///|
pub(all) struct ImpactOutput {
  name : String
  digest : String
  dependencies : Array[String]
} derive(ToJson)

///|
pub extend ImpactOutput with ToJson::{to_json}

///|
pub(all) struct DependencyImpact {
  include_drafts : Bool
  requested : Array[String]
  unknown : Array[String]
  outputs : Array[ImpactOutput]
} derive(ToJson)

///|
pub extend DependencyImpact with ToJson::{to_json}

///|
pub fn dependency_impact(
  graph : DependencyGraph,
  names : Array[String],
) -> DependencyImpact raise {
  if names.is_empty() || names.any(name => name.is_empty()) {
    raise InvalidInput("At least one nonempty dependency name is required")
  }
  if graph.pages < 0 {
    raise InvalidInput("Graph page count must be nonnegative")
  }
  let checked = parse_manifest(serialize_manifest(graph.artifacts))
  let selected : Map[String, Bool] = Map([])
  let requested : Array[String] = []
  for name in names {
    if !selected.contains(name) {
      selected[name] = true
      requested.push(name)
    }
  }
  requested.sort()
  let found : Map[String, Bool] = Map([])
  let outputs : Array[ImpactOutput] = []
  for artifact in graph_artifacts(checked.artifacts) {
    let dependencies : Array[String] = []
    for dep in artifact.dependencies {
      if selected.contains(dep.name) {
        found[dep.name] = true
        dependencies.push(dep.name)
      }
    }
    if !dependencies.is_empty() {
      outputs.push({
        name: artifact.name,
        digest: artifact.digest,
        dependencies,
      })
    }
  }
  {
    include_drafts: graph.include_drafts,
    requested,
    unknown: requested.filter(name => !found.contains(name)),
    outputs,
  }
}

///|
pub fn inspect_impact(
  input : String,
  names : Array[String],
  include_drafts? : Bool = false,
) -> DependencyImpact raise {
  if names.is_empty() || names.any(name => name.is_empty()) {
    raise InvalidInput("At least one nonempty dependency name is required")
  }
  dependency_impact(inspect_dependencies(input, include_drafts~), names)
}
