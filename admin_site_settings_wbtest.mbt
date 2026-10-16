///|
test "settings form escapes raw JSON and retains expected version" {
  let html = admin_site_settings_form(
    "token", "old\"<version>", "\n</textarea><script>bad</script>",
  )
  assert_true(html.contains("&lt;/textarea&gt;&lt;script&gt;"))
  assert_true(!html.contains("<script>"))
  assert_true(html.contains("old&quot;&lt;version&gt;"))
  assert_true(html.contains("schema only"))
  assert_true(html.contains("/workflow"))
}
