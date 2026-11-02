///|
test "embed selectors follow false-string and zero-string core semantics" {
  assert_eq(rest_embed_relations(None), None)
  for value in ["", "true", "1", "0", " , "] {
    assert_eq(rest_embed_relations(Some(value)), Some([]))
  }
  assert_eq(rest_embed_relations(Some("false")), Some(["false"]))
  assert_eq(
    rest_embed_relations(Some("author,wp:term author")),
    Some(["author", "wp:term"]),
  )
  let refused = try {
    rest_embed_relations(Some("x".repeat(1025))) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(refused)
}
