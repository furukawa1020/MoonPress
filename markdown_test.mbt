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
