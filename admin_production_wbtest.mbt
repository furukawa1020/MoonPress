///|
test "production plan escapes untrusted event fields" {
  let report : BuildReport = {
    pages: 1,
    written: 1,
    skipped: 0,
    deleted: 0,
    events: [],
    changes: [
      { action: "<write>", path: "</code><script>x</script>", reason: "\"<&'", },
    ],
  }
  let html = admin_production_changes(report)
  assert_true(html.contains("&lt;write&gt;"))
  assert_true(html.contains("&lt;/code&gt;&lt;script&gt;x&lt;/script&gt;"))
  assert_true(html.contains("&quot;&lt;&amp;&#39;"))
  assert_false(html.contains("<script>"))
}
