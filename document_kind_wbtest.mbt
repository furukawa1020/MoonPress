///|
test "post kind is default and explicit pages validate" {
  assert_eq(parse_document("# Title", "title").kind, "post")
  assert_eq(
    parse_document("---\n{\"kind\":\"page\"}\n---\n# About", "about").kind,
    "page",
  )
  for value in ["\"custom\"", "true", "null"] {
    let rejected = try {
      parse_document("---\n{\"kind\":" + value + "}\n---\n# Bad", "bad")
      |> ignore
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}
