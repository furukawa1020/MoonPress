///|
test "category metadata is distinct normalized and bounded" {
  let doc = parse_document(
    "---\n{\"tags\":[\"tag\"],\"categories\":[\" z \",\"月\",\"z\"]}\n---\n# Title",
    "a",
  )
  assert_eq(doc.tags, ["tag"])
  assert_eq(doc.categories, ["z", "月"])
  assert_eq(normalized_categories(" 月\r\n z \nz\n"), ["z", "月"])
  for value in ["true", "[1]", "[\"\"]", "[\"" + String::make(97, 'a') + "\"]"] {
    assert_true(
      try {
        parse_document("---\n{\"categories\":" + value + "}\n---\n# Bad", "a")
        |> ignore
        false
      } catch {
        _ => true
      },
    )
  }
}
