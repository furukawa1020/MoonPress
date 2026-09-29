///|
test "asterisk emphasis nests without recursive rendering" {
  assert_eq(
    @moonpress.render_inline(
      "*soft* **strong** **outer *inner* end** *outer **inner** end*",
    ),
    "<em>soft</em> <strong>strong</strong> <strong>outer <em>inner</em> end</strong> <em>outer <strong>inner</strong> end</em>",
  )
}

///|
test "emphasis preserves unsupported runs and boundary cases" {
  for
    source in [
      "***triple***", "****four****", "a*b*c", "a**b**c", "月*星*空", "😀*星*😀",
      "_plain_", "** unclosed", "*space *", "*", "**", "**a*",
    ] {
    assert_eq(@moonpress.render_inline(source), source)
  }
  assert_eq(
    @moonpress.render_inline("(*月*) **😀**"),
    "(<em>月</em>) <strong>😀</strong>",
  )
  assert_eq(
    @moonpress.render_inline("\u{3000}*月*\u{3000}"),
    "\u{3000}<em>月</em>\u{3000}",
  )
  assert_eq(@moonpress.render_inline("*a **b* c**"), "*a <strong>b* c</strong>")
  assert_eq(
    @moonpress.render_inline("**<script>&**"),
    "<strong>&lt;script&gt;&amp;</strong>",
  )
}

///|
test "emphasis spans code links and images while their contents stay literal" {
  let source = "**`*code*` [*label*](guide.html) ![*alt*](moon.svg)**"
  assert_eq(
    @moonpress.render_inline(source),
    "<strong><code>*code*</code> <a href=\"guide.html\">*label*</a> <img src=\"moon.svg\" alt=\"*alt*\"></strong>",
  )
  assert_eq(@moonpress.markdown_links(source), ["guide.html"])
  assert_eq(@moonpress.markdown_images(source), ["moon.svg"])
  assert_eq(@moonpress.render_inline("`**code**`"), "<code>**code**</code>")
}

///|
test "emphasis shares titles heading text and anchor identifiers" {
  let source = "# **Moon** *Press*\n## **月** `code`"
  assert_eq(@moonpress.page_title(source, "fallback"), "Moon Press")
  assert_eq(@moonpress.headings(source)[0].id, "mp-moon-press")
  assert_eq(@moonpress.headings(source)[1].text, "月 code")
  assert_true(@moonpress.render_toc(source).contains(">Moon Press</a>"))
  assert_true(
    @moonpress.render_markdown(source).contains(
      "<strong>Moon</strong> <em>Press</em>",
    ),
  )
}

///|
test "emphasis applies in every inline block but not across lines or fences" {
  let source = "- **list**\n\n1. *ordered*\n\n> **quote**\n\n*one\ntwo*\n\n~~~\n**literal** [fake](ghost.html)\n~~~"
  let html = @moonpress.render_markdown(source)
  assert_true(html.contains("<li><strong>list</strong></li>"))
  assert_true(html.contains("<li><em>ordered</em></li>"))
  assert_true(html.contains("<p><strong>quote</strong></p>"))
  assert_true(html.contains("<p>*one\ntwo*</p>"))
  assert_true(
    html.contains("<pre><code>**literal** [fake](ghost.html)\n</code></pre>"),
  )
  assert_eq(@moonpress.markdown_links(source), [])
}
