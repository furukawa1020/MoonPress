///|
pub(all) struct ReviewedBuildPlan {
  schema : Int
  review_id : String
  plan : DetailedBuildPlan
} derive(ToJson)

///|
pub extend ReviewedBuildPlan with ToJson::{to_json}

///|
fn review_identity(
  input : String,
  output : String,
  include_drafts : Bool,
  manifest : String,
  detail : DetailedBuildPlan,
) -> String {
  // An ordered JSON array prevents delimiter ambiguity. Include the complete
  // next manifest: unchanged dependencies are absent from the delta report.
  let payload : Json = [
    "moonpress-review-1",
    input.to_json(),
    output.to_json(),
    include_drafts.to_json(),
    manifest.to_json(),
    detail.to_json(),
  ]
  digest_text(payload.stringify())
}

///|
fn review_plan(
  input : String,
  output : String,
  include_drafts : Bool,
  state : OutputPlan,
) -> ReviewedBuildPlan raise {
  let detail = describe_plan(state.plan, state.previous)
  {
    schema: 1,
    review_id: review_identity(
      input,
      output,
      include_drafts,
      state.plan.manifest,
      detail,
    ),
    plan: detail,
  }
}

///|
pub fn review_build_plan(
  input : String,
  output : String,
  include_drafts? : Bool = false,
) -> ReviewedBuildPlan raise {
  let normalized = normalize_output(output)
  let lock = lock_output(normalized, shared=true)
  defer native_unlock_output(lock)
  let state = plan_output(input, normalized, include_drafts~)
  review_plan(input, output, include_drafts, state)
}
