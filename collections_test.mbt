///|
test "metadata digest ignores article body" {
  let a : @moonpress.Page = {
    output: "a.html",
    document: @moonpress.parse_document("# A\nOne", "a"),
  }
  let b : @moonpress.Page = {
    output: "a.html",
    document: @moonpress.parse_document("# A\nTwo", "a"),
  }
  assert_eq(@moonpress.metadata_digest(a), @moonpress.metadata_digest(b))
}

///|
test "URL encoding preserves Unicode filenames and encodes delimiters" {
  assert_eq(@moonpress.url_component("月 #?.html"), "%E6%9C%88%20%23%3F.html")
  assert_eq(@moonpress.tag_filename("MoonBit"), "tag-4d6f6f6e426974.html")
}

///|
test "collections escape metadata and URLs" {
  let page : @moonpress.Page = {
    output: "a\".html",
    document: { title: "<x>", description: "&", tags: [], body: "", },
  }
  let html = @moonpress.render_collection("<list>", [page])
  assert_true(html.contains("&lt;list&gt;"))
  assert_true(html.contains("a%22.html"))
  assert_true(html.contains("&lt;x&gt;"))
  assert_false(html.contains("<x>"))
}
