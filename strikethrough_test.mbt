///|
test "strikethrough shares balanced inline delimiters and visible text" {
  assert_eq(
    @moonpress.render_inline("~~old *word*~~"),
    "<del>old <em>word</em></del>",
  )
  assert_eq(
    @moonpress.render_inline("**outer ~~old~~ end**"),
    "<strong>outer <del>old</del> end</strong>",
  )
  assert_eq(
    @moonpress.page_title("# ~~Old~~ [Guide](guide.html)", "fallback"),
    "Old Guide",
  )
  assert_eq(@moonpress.headings("# ~~Old~~")[0].id, "mp-old")
  assert_eq(@moonpress.markdown_links("~~[Guide](guide.html)~~"), ["guide.html"])
  assert_eq(@moonpress.markdown_images("~~![Image](a.svg)~~"), ["a.svg"])
}

///|
test "strikethrough literal contexts and mismatched runs are preserved" {
  for
    literal in [
      "a~~b~~c", "~single~", "~~~triple~~~", "~~ unclosed", "~~open", "~~ ",
    ] {
    assert_eq(@moonpress.render_inline(literal), literal)
  }
  assert_eq(@moonpress.render_inline("\\~\\~literal\\~\\~"), "~~literal~~")
  assert_eq(@moonpress.render_inline("`~~<b>~~`"), "<code>~~&lt;b&gt;~~</code>")
  assert_eq(
    @moonpress.render_inline("[~~label~~](guide.html)"),
    "<a href=\"guide.html\">~~label~~</a>",
  )
  assert_eq(@moonpress.render_inline("~~<b>~~"), "<del>&lt;b&gt;</del>")
  assert_eq(@moonpress.render_inline("~~a *b~~ c*"), "~~a <em>b~~ c</em>")
}
