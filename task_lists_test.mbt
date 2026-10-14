///|
test "task lists are static accessible escaped output" {
  let html = @moonpress.render_markdown(
    "- [ ] Todo\n* [x] **Done**\n+ [X] `<b>`\n- ordinary\n1. [x] ordered",
  )
  assert_true(html.contains("disabled aria-label=\"Todo\"> Todo"))
  assert_true(
    html.contains("disabled checked aria-label=\"Done\"> <strong>Done</strong>"),
  )
  assert_true(html.contains("aria-label=\"&lt;b&gt;\"> <code>&lt;b&gt;</code>"))
  assert_true(html.contains("<li>ordinary</li>"))
  assert_true(html.contains("<li>[x] ordered</li>"))
  assert_true(!html.contains("<script"))
}

///|
test "task list references agree with rendering and literal contexts" {
  let source = "- [ ] [Guide](guide.html)\n- [X] ![Image](a.png)\n- \\[x] literal\n- [y] other\n~~~\n- [x] [Ignore](missing.html)\n~~~"
  assert_eq(@moonpress.markdown_links(source), ["guide.html"])
  assert_eq(@moonpress.markdown_images(source), ["a.png"])
  let html = @moonpress.render_markdown(source)
  assert_true(html.contains("<li>[x] literal</li>"))
  assert_true(html.contains("<li>[y] other</li>"))
  assert_true(html.contains("<pre><code>- [x] [Ignore](missing.html)"))
}
