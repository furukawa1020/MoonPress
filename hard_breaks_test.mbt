///|
test "explicit line breaks distinguish soft hard and terminal lines" {
  assert_eq(
    @moonpress.render_markdown("one  \ntwo\nthree\\\nfour"),
    "<p>one<br>\ntwo\nthree<br>\nfour</p>\n",
  )
  assert_eq(@moonpress.render_markdown("one\\\\\ntwo"), "<p>one\\\ntwo</p>\n")
  assert_eq(
    @moonpress.render_markdown("one\\\n\ntwo"),
    "<p>one\\</p>\n<p>two</p>\n",
  )
  assert_eq(@moonpress.render_markdown("one  "), "<p>one  </p>\n")
  assert_eq(
    @moonpress.render_markdown("> one  \n> two"),
    "<blockquote>\n<p>one<br>\ntwo</p>\n</blockquote>\n",
  )
}

///|
test "line breaks preserve code lists escaping and shared references" {
  let source = "[Guide](guide.html)\\\n![Image](a.svg)  \nnext\n\n- item  \n- other\n~~~\nliteral  \n~~~"
  let html = @moonpress.render_markdown(source)
  assert_eq(@moonpress.markdown_links(source), ["guide.html"])
  assert_eq(@moonpress.markdown_images(source), ["a.svg"])
  assert_true(html.contains("</a><br>\n<img"))
  assert_true(html.contains("<li>item  </li>"))
  assert_true(html.contains("<pre><code>literal  \n</code>"))
  assert_eq(
    @moonpress.render_markdown("<b>  \nend"),
    "<p>&lt;b&gt;<br>\nend</p>\n",
  )
  assert_eq(@moonpress.render_markdown("one  \r\ntwo"), "<p>one<br>\ntwo</p>\n")
}
