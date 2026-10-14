///|
test "tables compile aligned semantic escaped cells without phantom headings" {
  let source = "| Name | Value | End |\n| :--- | :---: | ---: |\n| **Moon** | `a|b` | <unsafe> |\n| # Hidden | 月😀 | \\| |"
  let html = @moonpress.render_markdown(source)
  assert_true(
    html.contains("<th scope=\"col\" style=\"text-align:left\">Name</th>"),
  )
  assert_true(
    html.contains("style=\"text-align:center\"><code>a|b</code></td>"),
  )
  assert_true(html.contains("style=\"text-align:right\">&lt;unsafe&gt;</td>"))
  assert_true(html.contains("# Hidden</td>"))
  assert_true(html.contains("月😀</td>"))
  assert_eq(@moonpress.headings(source).length(), 0)
  assert_eq(@moonpress.page_title(source, "fallback"), "fallback")
}

///|
test "table references share inline code and escape isolation" {
  let source = "A | B\n--- | ---\n[Guide](guide.html) | ![Image](a.svg)\n`[Ignore](missing.html)|code` | \\[Ignore](missing.html)"
  assert_eq(@moonpress.markdown_links(source), ["guide.html"])
  assert_eq(@moonpress.markdown_images(source), ["a.svg"])
  assert_true(
    @moonpress.render_markdown(source).contains(
      "<code>[Ignore](missing.html)|code</code>",
    ),
  )
}

///|
test "malformed table rows preserve content and block transitions" {
  let html = @moonpress.render_markdown(
    "A | B\n--- | ---\nvalid | row\nextra | cells | preserved\n# Heading\n~~~\nA | B\n--- | ---\n~~~",
  )
  assert_true(html.contains("</table>\n<p>extra | cells | preserved</p>"))
  assert_true(html.contains("<h1 id=\"mp-heading\">Heading</h1>"))
  assert_true(html.contains("<pre><code>A | B\n--- | ---\n</code>"))
  for
    source in [
      "A | B\n--- | --", "A | B\n--- | --- | ---", "A | B\n::--- | ---", "> A | B\n> --- | ---",
      "one\nA | B\n--- | ---",
    ] {
    assert_true(!@moonpress.render_markdown(source).contains("<table>"))
  }
  assert_true(
    @moonpress.render_markdown("| A |\n| --- |").contains("<tbody>\n</tbody>"),
  )
}
