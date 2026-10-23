///|
test "ordered HTML inline intake round trips without text reordering" {
  for
    (source, expected) in [
      (
        "<p>Before <strong>bold</strong> after <em>soft</em> end.</p>", "<p>Before <strong>bold</strong> after <em>soft</em> end.</p>\n",
      ),
      (
        "<p>A <a href='https://example.test/?a=1&amp;b=2'>link 月</a> then <code>x &lt; y</code>.</p>",
        "<p>A <a href=\"https://example.test/?a=1&amp;b=2\">link 月</a> then <code>x &lt; y</code>.</p>\n",
      ),
      (
        "<p><b>bold</b> &amp; <i>soft</i></p>", "<p><strong>bold</strong> &amp; <em>soft</em></p>\n",
      ),
      ("<p><code>`x`</code></p>", "<p><code>`x`</code></p>\n"),
    ] {
    assert_eq(render_markdown(wxr_body(source)), expected)
  }
  for
    source in [
      "<p>A<strong>B</strong>C</p>", "<p><strong> edge </strong></p>", "<p><a href='javascript:alert(1)'>x</a></p>",
      "<p><a href='//evil.test'>x</a></p>", "<p><a href='/x' onclick='x'>x</a></p>",
      "<p><a href='/x'><em>x</em></a></p>", "<p><span>x</span></p>", "<p>x<!-- lost -->y</p>",
      "<p><strong>x</p>", "<p class='x'>x</p>",
    ] {
    let mut refused = false
    try wxr_body(source) |> ignore catch {
      _ => refused = true
    }
    assert_true(refused)
  }
}
