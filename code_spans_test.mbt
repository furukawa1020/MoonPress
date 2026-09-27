///|
test "inline code closes only on an equal backtick run" {
  assert_eq(
    @moonpress.render_inline("a `` one ` two ``` three `` z"),
    "a <code>one ` two ``` three</code> z",
  )
  assert_eq(@moonpress.render_inline("`one``two`"), "<code>one``two</code>")
  assert_eq(@moonpress.render_inline("``<img>``"), "<code>&lt;img&gt;</code>")
}

///|
test "inline code spaces and unmatched delimiters" {
  assert_eq(@moonpress.render_inline("``  x  ``"), "<code> x </code>")
  assert_eq(@moonpress.render_inline("`   `"), "<code>   </code>")
  assert_eq(@moonpress.render_inline("` x`"), "<code> x</code>")
  assert_eq(
    @moonpress.render_inline("before ``unclosed`"),
    "before ``unclosed`",
  )
  assert_eq(@moonpress.render_inline("``"), "``")
  assert_eq(@moonpress.markdown_links("``unclosed [next](next.html)"), [
    "next.html",
  ])
}

///|
test "code span references stay literal in all consumers" {
  let source = "# `` [fake](ghost.html) ![fake](ghost.png) ` ``\n\n- ``[fake](ghost.html)``\n> ``![fake](ghost.png)``\n[next](next.html)"
  assert_eq(@moonpress.markdown_links(source), ["next.html"])
  assert_eq(@moonpress.markdown_images(source), [])
  assert_eq(
    @moonpress.headings(source)[0].text,
    "[fake](ghost.html) ![fake](ghost.png) `",
  )
  assert_false(@moonpress.render_toc(source).contains("href=\"ghost.html\""))
  assert_true(
    @moonpress.render_markdown(source).contains(
      "<code>[fake](ghost.html) ![fake](ghost.png) `</code>",
    ),
  )
}
