///|
test "publishing handoff escapes configured paths and never claims deployment" {
  let report : ReleaseReadiness = {
    review_id: digest_text("review"),
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
  let form = admin_export_form(report, "<token>\"")
  assert_true(form.contains("&lt;token&gt;&quot;"))
  assert_true(form.contains(report.review_id))
  assert_true(form.contains("action=\"/export-production\""))
  let html = admin_publish_report(report)
  assert_true(html.contains("&lt;unsafe&gt;"))
  assert_true(!html.contains("<x>"))
  assert_true(html.contains("not deployment confirmation"))
  assert_true(html.contains("Never upload .moonpress-preview"))
}
