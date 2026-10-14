///|
fn require_review(expected : String, actual : String) -> Unit raise {
  if !valid_digest(expected) {
    raise InvalidInput("Invalid review ID; inspect the build plan again")
  }
  if expected != actual {
    raise InvalidInput(
      "Reviewed build plan changed; inspect and review again before building",
    )
  }
}

///|
pub fn compile_reviewed_site(
  input : String,
  output : String,
  expected_review : String,
  include_drafts? : Bool = false,
) -> BuildReport raise {
  // Validate syntax before filesystem work, then revalidate identity under lock.
  require_review(expected_review, expected_review)
  let normalized = normalize_output(output)
  let lock = lock_output(normalized, shared=false)
  defer native_unlock_output(lock)
  let state = plan_output(input, normalized, include_drafts~)
  let review = review_plan(input, output, include_drafts, state)
  require_review(expected_review, review.review_id)
  // Do not invoke compile_site here: that would read a second, unreviewed plan.
  apply_plan(normalized, state.plan)
  state.plan.report
}
