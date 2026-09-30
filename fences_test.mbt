///|
test "long fences keep shorter and mixed delimiters literal" {
  let source = "````markdown\n```\n# Hidden\n[x](missing.html)\n![x](missing.png)\n~~~\n```` text\n`````\n# Real"
  let html = @moonpress.render_markdown(source)
  assert_true(
    html.contains(
      "<pre><code class=\"language-markdown\">```\n# Hidden\n[x](missing.html)\n![x](missing.png)\n~~~\n```` text\n</code></pre>",
    ),
  )
  assert_eq(@moonpress.page_title(source, "fallback"), "Real")
  assert_eq(@moonpress.headings(source).map(h => h.id), ["mp-real"])
  assert_eq(@moonpress.markdown_links(source), [])
  assert_eq(@moonpress.markdown_images(source), [])
}

///|
test "tilde fences support CRLF and trailing closing whitespace" {
  assert_eq(
    @moonpress.render_markdown("~~~html\r\n<b>\r\n~~~ \t\r\ntext"),
    "<pre><code class=\"language-html\">&lt;b&gt;\n</code></pre>\n<p>text</p>\n",
  )
  assert_eq(
    @moonpress.render_markdown("~~~~\nx\n~~~"),
    "<pre><code>x\n~~~\n</code></pre>\n",
  )
  assert_eq(
    @moonpress.render_markdown("~~~\n~~~"),
    "<pre><code></code></pre>\n",
  )
}

///|
test "invalid opener and indented delimiters remain outside fences" {
  let source = "```invalid`info\n# Visible\n  ~~~\n[next](next.html)"
  assert_eq(@moonpress.headings(source).map(h => h.id), ["mp-visible"])
  assert_eq(@moonpress.markdown_links(source), ["next.html"])
  assert_false(@moonpress.render_markdown(source).contains("<pre>"))
}
