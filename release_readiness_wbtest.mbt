///|
test "publishing handoff escapes configured paths and never claims deployment" {
  let report : ReleaseReadiness = {
    output: "<unsafe>",
    current: true,
    ready_posts: 2,
    drafts: 1,
    outputs: 4,
    pending_writes: 0,
    pending_deletes: 0,
    manifest_changed: false,
    base_url: Some("https://example.org/?q=\"<x>"),
  }
  let html = admin_publish_report(report)
  assert_true(html.contains("&lt;unsafe&gt;"))
  assert_true(!html.contains("<x>"))
  assert_true(html.contains("not deployment confirmation"))
  assert_true(html.contains("Never upload .moonpress-preview"))
}
