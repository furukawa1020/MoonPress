///|
pub(all) struct PlannedOutput {
  name : String
  action : String
  reason : String
  old_digest : String?
  new_digest : String?
  dependencies : Array[DependencyChange]
} derive(ToJson)

///|
pub extend PlannedOutput with ToJson::{to_json}

///|
pub(all) struct DetailedBuildPlan {
  summary : BuildReport
  outputs : Array[PlannedOutput]
} derive(ToJson)

///|
pub extend DetailedBuildPlan with ToJson::{to_json}

///|
fn describe_plan(
  plan : BuildPlan,
  previous : Map[String, Artifact],
) -> DetailedBuildPlan raise {
  let next = artifact_map(plan.pending.map(item => item.artifact))
  let outputs : Array[PlannedOutput] = []
  for event in plan.report.changes {
    let before = previous.get(event.path)
    let after = next.get(event.path)
    outputs.push({
      name: event.path,
      action: event.action,
      reason: event.reason,
      old_digest: before.map(a => a.digest),
      new_digest: after.map(a => a.digest),
      dependencies: dependency_changes(
        match before {
          None => []
          Some(a) => a.dependencies
        },
        match after {
          None => []
          Some(a) => a.dependencies
        },
      ),
    })
  }
  outputs.sort_by((a, b) => a.name.compare(b.name))
  { summary: plan.report, outputs, }
}

///|
pub fn inspect_build_plan(
  input : String,
  output : String,
  include_drafts? : Bool = false,
) -> DetailedBuildPlan raise {
  let output = normalize_output(output)
  let lock = lock_output(output, shared=true)
  defer native_unlock_output(lock)
  let state = plan_output(input, output, include_drafts~)
  describe_plan(state.plan, state.previous)
}
