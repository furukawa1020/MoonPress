///|
pub(all) struct ReleaseReadiness {
  review_id : String
  output : String
  current : Bool
  ready_posts : Int
  drafts : Int
  outputs : Int
  pending_writes : Int
  pending_deletes : Int
  manifest_changed : Bool
  base_url : String?
} derive(ToJson)

///|
pub extend ReleaseReadiness with ToJson::{to_json}

///|
pub fn inspect_release_readiness(input : String) -> ReleaseReadiness raise {
  if input.is_empty() {
    raise InvalidInput("Site directory must not be empty")
  }
  let output = input.trim_end(chars="/").to_owned() + "/.moonpress-build"
  let review = review_build_plan(input, output)
  let inventory = inspect_posts(input)
  let drafts = inventory.posts.filter(post => post.draft).length()
  let summary = review.plan.summary
  {
    review_id: review.review_id,
    output,
    current: review.previous_manifest_digest is Some(_) &&
    !review.manifest_changed &&
    summary.written == 0 &&
    summary.deleted == 0,
    ready_posts: inventory.posts.length() - drafts,
    drafts,
    outputs: review.plan.outputs
    .filter(item => item.action != "delete")
    .length(),
    pending_writes: summary.written,
    pending_deletes: summary.deleted,
    manifest_changed: review.manifest_changed,
    base_url: read_site_config(input).base_url,
  }
}
