///|
test "escape untrusted HTML" {
  assert_eq(
    @moonpress.escape_html("<script>\"&'</script>"),
    "&lt;script&gt;&quot;&amp;&#39;&lt;/script&gt;",
  )
}

///|
test "headings paragraphs and CRLF" {
  assert_eq(
    @moonpress.render_markdown("# Hello\r\n\nworld\nagain"),
    "<h1>Hello</h1>\n<p>world\nagain</p>\n",
  )
}

///|
test "code fences preserve syntax and escape HTML" {
  assert_eq(
    @moonpress.render_markdown("```html\n<b>\n```"),
    "<pre><code>&lt;b&gt;\n</code></pre>\n",
  )
}

///|
test "unterminated fence is closed" {
  assert_eq(
    @moonpress.render_markdown("```\nx"),
    "<pre><code>x\n</code></pre>\n",
  )
}

///|
test "source cannot inject template placeholders" {
  assert_eq(
    @moonpress.apply_layout(
      "<title>{{title}}</title>{{content}}", "<x>", "{{title}}",
    ),
    "<title>&lt;x&gt;</title>{{title}}",
  )
}

///|
test "Japanese title" {
  assert_eq(
    @moonpress.page_title("# 月のサイト\n本文", "fallback"),
    "月のサイト",
  )
}
