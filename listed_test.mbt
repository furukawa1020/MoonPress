///|
test "listed defaults true and is independent of draft selection" {
  assert_true(@moonpress.parse_document("# Home", "home").listed)
  let standalone = @moonpress.parse_document(
    "---\n{\"listed\":false,\"draft\":true}\n---\n# Home", "home",
  )
  assert_false(standalone.listed)
  assert_true(standalone.draft)
  assert_true(
    @moonpress.parse_document("---\n{\"listed\":true}\n---\n# Home", "home").listed,
  )
}

///|
test "listed metadata types are strict even for drafts" {
  for value in ["null", "0", "\"false\"", "[]", "{}"] {
    let rejected = try {
      let _ = @moonpress.parse_document(
        "---\n{\"draft\":true,\"listed\":" + value + "}\n---\n# Home",
        "home",
      )
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}
