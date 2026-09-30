///|
test "safe language tokens preserve spelling and ignore extra metadata" {
  for
    name in [
      "moonbit",
      "sh",
      "C++",
      "objective-c",
      "a_b",
      "123",
      String::make(64, 'x'),
    ] {
    for fence in ["```", "~~~"] {
      assert_eq(
        @moonpress.render_markdown(
          fence + " \t" + name + "\tignored <unsafe>\n<x>&\n" + fence,
        ),
        "<pre><code class=\"language-" +
        name +
        "\">&lt;x&gt;&amp;\n</code></pre>\n",
      )
    }
  }
}

///|
test "invalid first info token falls back without emitting attributes" {
  for
    info in [
      "",
      " \t",
      "x\"onclick=\"bad",
      "x<bad>",
      "{.moonbit}",
      "a/b",
      "日本語",
      "x\u{0000}",
      "x\u{00a0}y",
      String::make(65, 'x'),
    ] {
    assert_eq(
      @moonpress.render_markdown("~~~" + info + "\nx\n~~~"),
      "<pre><code>x\n</code></pre>\n",
    )
  }
}

///|
test "language is reset for each fence including unclosed CRLF fences" {
  assert_eq(
    @moonpress.render_markdown(
      "```moonbit\r\nx\r\n```\r\n~~~\r\ny\r\n~~~\r\n```sh\r\nz",
    ),
    "<pre><code class=\"language-moonbit\">x\n</code></pre>\n<pre><code>y\n</code></pre>\n<pre><code class=\"language-sh\">z\n</code></pre>\n",
  )
}
