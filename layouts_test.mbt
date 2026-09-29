///|
test "layout metadata is optional and preserves safe Unicode filenames" {
  assert_eq(@moonpress.parse_document("# Default", "x").layout, None)
  for name in ["post.html", "記事.html", "landing-page_2.html"] {
    let doc = @moonpress.parse_document(
      "---\n{\"layout\":\"" + name + "\"}\n---\n# Page",
      "x",
    )
    assert_eq(doc.layout, Some(name))
  }
}

///|
test "layout metadata rejects traversal whitespace invalid names and wrong types" {
  for
    value in [
      "null", "true", "42", "[]", "\"\"", "\".html\"", "\"../post.html\"", "\"/post.html\"",
      "\"sub/post.html\"", "\"post.HTML\"", "\" post.html\"", "\"a b.html\"", "\"a\\\\b.html\"",
      "\"a:post.html\"", "\"a\\u0000.html\"",
    ] {
    try
      @moonpress.parse_document(
        "---\n{\"draft\":true,\"layout\":" + value + "}\n---\n# Page",
        "x",
      )
    catch {
      _ => ()
    } noraise {
      _ => fail("expected invalid layout: " + value)
    }
  }
}

///|
test "collection dependencies ignore page layout selection" {
  let a : @moonpress.Page = {
    output: "a.html",
    document: @moonpress.parse_document("# Page", "a"),
  }
  let b : @moonpress.Page = {
    output: "a.html",
    document: @moonpress.parse_document(
      "---\n{\"layout\":\"post.html\"}\n---\n# Page", "a",
    ),
  }
  assert_eq(@moonpress.metadata_digest(a), @moonpress.metadata_digest(b))
}
