///|
test "setext shares heading IDs visible titles TOC and references" {
  let source = "**Moon** [Guide](guide.html)\r\n==== \t\r\n\nSection\n---\n# Moon Guide"
  assert_eq(@moonpress.page_title(source, "fallback"), "Moon Guide")
  let headings = @moonpress.headings(source)
  assert_eq(headings.length(), 3)
  assert_eq(headings[0].level, 1)
  assert_eq(headings[0].id, "mp-moon-guide")
  assert_eq(headings[1].level, 2)
  assert_eq(headings[2].id, "mp-moon-guide-2")
  assert_true(@moonpress.render_toc(source).contains("href=\"#mp-section\""))
  assert_eq(@moonpress.markdown_links(source), ["guide.html"])
}

///|
test "setext precedence is limited to one paragraph line" {
  assert_eq(
    @moonpress.render_markdown("Text\n---"),
    "<h2 id=\"mp-text\">Text</h2>\n",
  )
  assert_eq(@moonpress.render_markdown("Text\n\n---"), "<p>Text</p>\n<hr>\n")
  assert_eq(@moonpress.render_markdown("Text\n- - -"), "<p>Text</p>\n<hr>\n")
  assert_eq(@moonpress.render_markdown("A\nB\n---"), "<p>A\nB</p>\n<hr>\n")
  for
    source in [
      "Text\n==", "Text\n ===", "> Quote\n===", "- Item\n===", "~~~\nHidden\n===\n~~~",
    ] {
    assert_eq(@moonpress.headings(source).length(), 0)
  }
}
