///|
test "all ASCII punctuation can be escaped without reparsing" {
  let punctuation = "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~"
  for c in punctuation {
    assert_eq(
      @moonpress.render_inline("\\" + c.to_string()),
      @moonpress.escape_html(c.to_string()),
    )
  }
  assert_eq(
    @moonpress.render_inline("\\*literal\\* \\`code\\` \\[x](ghost.html)"),
    "*literal* `code` [x](ghost.html)",
  )
  assert_eq(@moonpress.markdown_links("\\[x](ghost.html)"), [])
  assert_eq(@moonpress.markdown_images("!\\[x](ghost.png)"), [])
}

///|
test "non punctuation trailing and code backslashes stay literal" {
  assert_eq(
    @moonpress.render_inline("\\a \\月 \\😀 \\ \\"),
    "\\a \\月 \\😀 \\ \\",
  )
  assert_eq(@moonpress.render_inline("`\\*`"), "<code>\\*</code>")
  assert_eq(
    @moonpress.render_markdown("~~~\n\\*\n~~~"),
    "<pre><code>\\*\n</code></pre>\n",
  )
  assert_eq(@moonpress.render_inline("\\\\*yes*"), "\\<em>yes</em>")
  assert_eq(@moonpress.render_inline("**a \\* b**"), "<strong>a * b</strong>")
}

///|
test "escaped label brackets are plain text and destination syntax stays strict" {
  let source = "[a\\]\\[月😀\\*](next.html) ![\\<x\\>](pic.png)"
  assert_eq(
    @moonpress.render_inline(source),
    "<a href=\"next.html\">a][月😀*</a> <img src=\"pic.png\" alt=\"&lt;x&gt;\">",
  )
  assert_eq(@moonpress.markdown_links(source), ["next.html"])
  assert_eq(@moonpress.markdown_images(source), ["pic.png"])
  assert_eq(
    @moonpress.render_inline("[a\\](b](next.html)"),
    "<a href=\"next.html\">a](b</a>",
  )
  assert_eq(
    @moonpress.render_inline("\\![x](next.html)"),
    "!<a href=\"next.html\">x</a>",
  )
  assert_eq(@moonpress.markdown_links("[x](next\\.html)"), ["next\\.html"])
  assert_false(@moonpress.allowed_href("next\\.html"))
}

///|
test "headings title and block markers share literal punctuation" {
  let source = "# A\\*B [\\[label\\]](next.html)\n\\# literal\n\\- item\n\\> quote"
  assert_eq(@moonpress.page_title(source, "fallback"), "A*B [label]")
  assert_eq(@moonpress.headings(source).map(h => h.id), ["mp-a-b-label"])
  let html = @moonpress.render_markdown(source)
  assert_true(html.contains("<p># literal\n- item\n&gt; quote</p>"))
  assert_eq(
    @moonpress.render_markdown("- \\*item\\*\n> \\`quote\\`"),
    "<ul>\n<li>*item*</li>\n</ul>\n<blockquote>\n<p>`quote`</p>\n</blockquote>\n",
  )
}
