///|
pub(all) struct ReviewedBuildPlan {
  schema : Int
  review_id : String
  previous_manifest_digest : String?
  next_manifest_digest : String
  manifest_changed : Bool
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
  previous_manifest? : String? = None,
) -> String {
  // An ordered JSON array prevents delimiter ambiguity. Include the complete
  // next manifest: unchanged dependencies are absent from the delta report.
  let payload : Json = [
    "moonpress-review-2",
    input.to_json(),
    output.to_json(),
    include_drafts.to_json(),
    manifest.to_json(),
    previous_manifest.to_json(),
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
    schema: 2,
    previous_manifest_digest: state.previous_manifest.map(digest_text),
    next_manifest_digest: digest_text(state.plan.manifest),
    manifest_changed: state.previous_manifest != Some(state.plan.manifest),
    review_id: review_identity(
      input,
      output,
      include_drafts,
      state.plan.manifest,
      detail,
      previous_manifest=state.previous_manifest,
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
