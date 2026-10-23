///|
test "HTML strikethrough accepts representable spans and rejects lossy attributes" {
  assert_eq(
    render_markdown(wxr_body("<p>Before <del>old</del> after.</p>")),
    "<p>Before <del>old</del> after.</p>\n",
  )
  assert_eq(
    render_markdown(wxr_body("<p><s>Removed</s></p>")),
    "<p><del>Removed</del></p>\n",
  )
  for
    source in ["<p><del onclick='x'>old</del></p>", "<p><del> edge </del></p>"] {
    let mut refused = false
    try wxr_body(source) |> ignore catch {
      _ => refused = true
    }
    assert_true(refused)
  }
}
