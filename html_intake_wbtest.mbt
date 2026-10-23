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

///|
test "flat HTML lists preserve order starts inline and following blocks" {
  assert_eq(
    render_markdown(
      wxr_body(
        "<ul><li>First <strong>bold</strong> end</li><li>Second &amp; 月</li></ul><p>After</p>",
      ),
    ),
    "<ul>\n<li>First <strong>bold</strong> end</li>\n<li>Second &amp; 月</li>\n</ul>\n<p>After</p>\n",
  )
  assert_eq(
    render_markdown(
      wxr_body("<ol start='3'><li>Third</li><li>Fourth</li></ol>"),
    ),
    "<ol start=\"3\">\n<li>Third</li>\n<li>Fourth</li>\n</ol>\n",
  )
  for
    source in [
      "<ul></ul>", "<ul><li></li></ul>", "<ul><li>A<ul><li>B</li></ul></li></ul>",
      "<ul><li><p>A</p></li></ul>", "<ol start='0'><li>A</li></ol>", "<ol start='1000000000'><li>A</li></ol>",
      "<ol><li value='4'>A</li></ol>", "<ul>lost<li>A</li></ul>",
    ] {
    let mut refused = false
    try wxr_body(source) |> ignore catch {
      _ => refused = true
    }
    assert_true(refused)
  }
}

///|
test "static WordPress blocks validate wrappers and HTML agreement" {
  assert_eq(
    render_markdown(
      wxr_body(
        "<!-- wp:paragraph --><p>Before <strong>bold</strong> end.</p><!-- /wp:paragraph --><!-- wp:heading {\"level\":3} --><h3 class=\"wp-block-heading\">Heading</h3><!-- /wp:heading -->",
      ),
    ),
    "<p>Before <strong>bold</strong> end.</p>\n<h3 id=\"mp-heading\">Heading</h3>\n",
  )
  assert_eq(
    render_markdown(
      wxr_body(
        "<!-- wp:list {\"ordered\":true,\"start\":3} --><ol start=\"3\" class=\"wp-block-list\"><!-- wp:list-item --><li>Third</li><!-- /wp:list-item --><!-- wp:list-item --><li>Fourth</li><!-- /wp:list-item --></ol><!-- /wp:list -->",
      ),
    ),
    "<ol start=\"3\">\n<li>Third</li>\n<li>Fourth</li>\n</ol>\n",
  )
  for
    source in [
      "<!-- wp:paragraph --><p>A</p>", "<!-- wp:paragraph --><p>A</p><!-- /wp:heading -->",
      "<!-- wp:paragraph --><h2>A</h2><!-- /wp:paragraph -->", "<!-- wp:heading {\"level\":3} --><h2>A</h2><!-- /wp:heading -->",
      "<!-- wp:heading {\"level\":7} --><h2>A</h2><!-- /wp:heading -->", "<!-- wp:heading {\"align\":\"center\"} --><h2>A</h2><!-- /wp:heading -->",
      "<!-- wp:list {\"ordered\":true,\"start\":3} --><ol><li>A</li></ol><!-- /wp:list -->",
      "<!-- wp:list {\"ordered\":\"true\"} --><ol><li>A</li></ol><!-- /wp:list -->",
      "<!-- wp:paragraph --><p class=\"arbitrary\">A</p><!-- /wp:paragraph -->",
      "<!-- wp:paragraph --><p>A</p><p>B</p><!-- /wp:paragraph -->", "<!-- wp:list-item --><li>A</li><!-- /wp:list-item -->",
      "<!-- wp:latest-posts /-->", "<!-- wp:plugin/block --><p>A</p><!-- /wp:plugin/block -->",
      "<!-- /wp:paragraph -->", "<!-- wp:paragraph {} /-->",
    ] {
    let mut refused = false
    try wxr_body(source) |> ignore catch {
      _ => refused = true
    }
    assert_true(refused)
  }
}

///|
test "HTML hard breaks retain paragraph line order" {
  assert_eq(
    render_markdown(wxr_body("<p>First<br>Second<br />月</p>")),
    "<p>First<br>\nSecond<br>\n月</p>\n",
  )
  for
    text in [
      "<h2>A<br>B</h2>", "<p>A<br><br>B</p>", "<p>A<br></p>", "<p><br>A</p>", "<p>A<br onclick='x'>B</p>",
    ] {
    let rejected = try {
      wxr_body(text) |> ignore
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}
