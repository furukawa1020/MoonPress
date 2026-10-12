///|
pub(all) struct DependencyGraph {
  pages : Int
  include_drafts : Bool
  artifacts : Array[Artifact]
} derive(ToJson)

///|
pub extend DependencyGraph with ToJson::{to_json}

///|
fn graph_artifacts(artifacts : Array[Artifact]) -> Array[Artifact] {
  let result = artifacts.map(artifact => {
    let dependencies = artifact.dependencies.map(dep => dep)
    dependencies.sort_by((a, b) => a.name.compare(b.name))
    { ..artifact, dependencies, }
  })
  result.sort_by((a, b) => a.name.compare(b.name))
  result
}

///|
pub fn inspect_dependencies(
  input : String,
  include_drafts? : Bool = false,
) -> DependencyGraph raise {
  let plan = plan_site(input, Map([]), None, include_drafts~)
  {
    pages: plan.report.pages,
    include_drafts,
    artifacts: graph_artifacts(plan.pending.map(item => item.artifact)),
  }
}
