///|
test "ATX separators levels and outer whitespace" {
  for level = 1; level <= 6; level = level + 1 {
    let marker = String::make(level, '#')
    for separator in [" ", "\t", " \t "] {
      let source = marker + separator + "Title\t ### \t\r\n"
      assert_eq(
        @moonpress.render_markdown(source),
        "<h\{level} id=\"mp-title\">Title</h\{level}>\n",
      )
      assert_eq(@moonpress.headings(source).map(h => h.text), ["Title"])
    }
  }
  assert_eq(
    @moonpress.render_markdown("# \u{00a0}Title\u{00a0}"),
    "<h1 id=\"mp-title\">\u{00a0}Title\u{00a0}</h1>\n",
  )
}

///|
test "empty headings have stable IDs and first H1 fallback" {
  assert_eq(@moonpress.headings("#\n##\t\n# ###").map(h => h.id), [
    "mp-section", "mp-section-2", "mp-section-3",
  ])
  assert_eq(@moonpress.page_title("#\n# Later", "filename"), "filename")
  assert_eq(@moonpress.page_title("# ###\n# Later", "filename"), "filename")
  assert_eq(
    @moonpress.render_markdown("######"),
    "<h6 id=\"mp-section\"></h6>\n",
  )
}

///|
test "closing hashes require whitespace and escaped hashes stay text" {
  for
    (source, title) in [
      ("# C#", "C#"),
      ("# Title###", "Title###"),
      ("# Title ### tail", "Title ### tail"),
      ("# Title \\###", "Title ###"),
      ("# Title # #", "Title #"),
      ("# **Title** ###", "Title"),
      ("# `#` ###", "#"),
    ] {
    assert_eq(@moonpress.page_title(source, "fallback"), title)
    assert_eq(@moonpress.headings(source).map(h => h.text), [title])
  }
}

///|
test "unsupported markers and fences do not become headings" {
  let source = "####### Seven\n#No separator\n # Indented\n#\u{00a0}Unicode separator\n\\# Escaped\n~~~\n# Hidden ###\n~~~"
  assert_true(@moonpress.headings(source).is_empty())
  assert_eq(@moonpress.page_title(source, "fallback"), "fallback")
  assert_true(
    @moonpress.render_markdown(source).contains(
      "<pre><code># Hidden ###\n</code></pre>",
    ),
  )
}

///|
test "normalized headings retain inline references and close block groups" {
  let source = "paragraph\n#\t[Next](next.html) ###\n- item\n##\n> quote\n### End ###"
  assert_eq(@moonpress.markdown_links(source), ["next.html"])
  assert_eq(@moonpress.headings(source).map(h => h.id), [
    "mp-next", "mp-section", "mp-end",
  ])
  assert_true(
    @moonpress.render_markdown(source).contains(
      "</ul>\n<h2 id=\"mp-section\"></h2>",
    ),
  )
  assert_true(@moonpress.render_toc(source).contains(">Next</a>"))
}
