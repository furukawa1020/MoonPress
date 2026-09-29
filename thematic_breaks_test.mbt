///|
test "thematic breaks accept homogeneous markers and ASCII spacing" {
  for source in ["---", "***", "___", "----", "* * *", "_\t_ _\t", "- - - \t"] {
    assert_eq(@moonpress.render_markdown(source), "<hr>\n")
    assert_true(@moonpress.headings(source).is_empty())
    assert_eq(@moonpress.markdown_links(source), [])
    assert_eq(@moonpress.page_title(source, "fallback"), "fallback")
  }
}

///|
test "thematic breaks close groups and precede list parsing" {
  assert_eq(
    @moonpress.render_markdown(
      "before\n---\nafter\n- item\n- - -\n1. item\n___\n> quote\n* * *\n# End",
    ),
    "<p>before</p>\n<hr>\n<p>after</p>\n<ul>\n<li>item</li>\n</ul>\n<hr>\n<ol>\n<li>item</li>\n</ol>\n<hr>\n<blockquote>\n<p>quote</p>\n</blockquote>\n<hr>\n<h1 id=\"mp-end\">End</h1>\n",
  )
}

///|
test "unsupported separators and fenced separators retain existing rules" {
  for
    source in [
      "--", "**", "__", " - - -", "\t___", "_-_", "---x", "_\u{3000}_\u{3000}_",
    ] {
    assert_false(@moonpress.render_markdown(source).contains("<hr>"))
  }
  assert_eq(@moonpress.render_markdown("- * -"), "<ul>\n<li>* -</li>\n</ul>\n")
  assert_eq(
    @moonpress.render_markdown("~~~\r\n---\r\n***\r\n___\r\n~~~"),
    "<pre><code>---\n***\n___\n</code></pre>\n",
  )
}

///|
test "thematic breaks preserve frontmatter and following headings" {
  let doc = @moonpress.parse_document(
    "---\n{\"title\":\"Metadata\"}\n---\n---\n# Body\n___", "fallback",
  )
  assert_eq(doc.title, "Metadata")
  assert_eq(
    @moonpress.render_markdown(doc.body),
    "<hr>\n<h1 id=\"mp-body\">Body</h1>\n<hr>\n",
  )
  assert_eq(
    @moonpress.parse_document("***\n# Title", "fallback").title,
    "Title",
  )
  try @moonpress.parse_document("---\n# Not metadata", "fallback") catch {
    _ => ()
  } noraise {
    _ => fail("expected invalid frontmatter")
  }
}
