///|
test "block transitions preserve output and isolate code" {
  let source = "before\r\n## Two\r\n```text\r\n# Not a title\r\n[x](missing.html)\r\n```\r\n# Real\r\n[next](next.html)\r\nend"
  assert_eq(
    @moonpress.render_markdown(source),
    "<p>before</p>\n<h2>Two</h2>\n<pre><code># Not a title\n[x](missing.html)\n</code></pre>\n<h1>Real</h1>\n<p><a href=\"next.html\">next</a>\nend</p>\n",
  )
  assert_eq(@moonpress.page_title(source, "fallback"), "Real")
  assert_eq(@moonpress.markdown_links(source), ["next.html"])
}

///|
test "unclosed and empty fences use the same block rules" {
  let source = "```\n```\ntext\n```\n# Hidden\n[hidden](missing.html)"
  assert_eq(
    @moonpress.render_markdown(source),
    "<pre><code></code></pre>\n<p>text</p>\n<pre><code># Hidden\n[hidden](missing.html)\n</code></pre>\n",
  )
  assert_eq(@moonpress.page_title(source, "fallback"), "fallback")
  assert_eq(@moonpress.markdown_links(source), [])
  assert_eq(@moonpress.render_markdown(""), "")
}

///|
test "flat lists and quotes close on block transitions" {
  assert_eq(
    @moonpress.render_markdown(
      "intro\n- one\n* two\n+ three\n003. first\n8. second\n> quote\n> next\nend\n# H",
    ),
    "<p>intro</p>\n<ul>\n<li>one</li>\n<li>two</li>\n<li>three</li>\n</ul>\n<ol start=\"3\">\n<li>first</li>\n<li>second</li>\n</ol>\n<blockquote>\n<p>quote\nnext</p>\n</blockquote>\n<p>end</p>\n<h1>H</h1>\n",
  )
  assert_eq(
    @moonpress.render_markdown("1. a\n\n1. b"),
    "<ol>\n<li>a</li>\n</ol>\n<ol>\n<li>b</li>\n</ol>\n",
  )
}

///|
test "list and quote content stays escaped and links are checked" {
  let source = "- [next](next.html)\r\n- `<b>`\r\n> <script>\r\n> [home](index.html)\r\n> # not a title\r\n```\r\n- [hidden](missing.html)\r\n```"
  let html = @moonpress.render_markdown(source)
  assert_true(html.contains("<li><a href=\"next.html\">next</a></li>"))
  assert_true(html.contains("<li><code>&lt;b&gt;</code></li>"))
  assert_true(html.contains("&lt;script&gt;"))
  assert_eq(@moonpress.markdown_links(source), ["next.html", "index.html"])
  assert_eq(@moonpress.page_title(source, "fallback"), "fallback")
}

///|
test "unsupported nesting and oversized ordered markers remain text" {
  assert_eq(
    @moonpress.render_markdown("  - nested\n1000000000. large\n-\n>no-space"),
    "<p>  - nested\n1000000000. large\n-\n&gt;no-space</p>\n",
  )
  assert_eq(
    @moonpress.render_markdown("0. zero\n- \n>"),
    "<ol start=\"0\">\n<li>zero</li>\n</ol>\n<ul>\n<li></li>\n</ul>\n<blockquote>\n<p></p>\n</blockquote>\n",
  )
}
