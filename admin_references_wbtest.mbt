///|
test "reference UI escapes evidence and links only safe article sources" {
  let edge : ReferenceEdge = {
    source: "content/a&b.md",
    output: "<output>",
    kind: "<kind>",
    url: "\"><script>x</script>",
    target: "<target>",
    fragment: Some("<fragment>"),
  }
  let html = admin_reference_rows("<title>", [edge])
  assert_true(html.contains("/edit?name=a%26b.md"))
  assert_true(html.contains("content/a&amp;b.md"))
  for value in ["output", "kind", "target", "fragment", "title"] {
    assert_true(html.contains("&lt;" + value + "&gt;"))
  }
  assert_false(html.contains("<script>"))
  assert_false(html.contains("href=\"<target>"))
  assert_false(admin_reference_source("content/../secret.md").contains("<a "))
  assert_false(admin_reference_source("layout.html").contains("<a "))
  assert_true(
    admin_reference_rows("Empty", []).contains(
      "does not prove deletion is safe",
    ),
  )
}
