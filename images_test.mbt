///|
test "images escape attributes and remain distinct from links" {
  let text = "![<月> & \"alt\"](moon.png?q=1&x=2) [next](next.html)"
  assert_eq(
    @moonpress.render_inline(text),
    "<img src=\"moon.png?q=1&amp;x=2\" alt=\"&lt;月&gt; &amp; &quot;alt&quot;\"> <a href=\"next.html\">next</a>",
  )
  assert_eq(@moonpress.markdown_links(text), ["next.html"])
  assert_eq(@moonpress.markdown_images(text), ["moon.png?q=1&x=2"])
  assert_eq(
    @moonpress.render_inline("![](moon.png)"),
    "<img src=\"moon.png\" alt=\"\">",
  )
}

///|
test "images in code are literal and incomplete images survive" {
  let text = "`![example](ghost.png)` ![real](real.png)\n```\n![example](ghost.png)\n```\n- ![list](list.png)\n> ![quote](quote.png)"
  assert_eq(@moonpress.markdown_images(text), [
    "real.png", "list.png", "quote.png",
  ])
  assert_eq(
    @moonpress.render_inline("before ![unfinished"),
    "before ![unfinished",
  )
  assert_eq(@moonpress.render_inline("![x](bad"), "![x](bad")
}

///|
test "source URLs reject non-image schemes and missing paths" {
  for
    src in [
      "mailto:x@y", "data:image/png;base64,AA", "javascript:x", "//host/x", "#only",
      "?only", "",
    ] {
    assert_false(@moonpress.render_inline("![x](" + src + ")").contains("<img"))
    let rejected = try {
      @moonpress.validate_sources([src], ["x.png"])
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  @moonpress.validate_sources(
    ["https://example.org/a.png", "/project/月.png"],
    ["月.png"],
    base_path="/project/",
  )
}

///|
test "template source scanning respects comments and quotes" {
  assert_eq(
    @moonpress.template_sources(
      "<!-- <img src='ghost.png'> --><img title=\"src='fake' >\" SRC='moon.png?a=1&amp;b=2'>",
    ),
    ["moon.png?a=1&b=2"],
  )
  for html in ["<img src=moon.png>", "<img src='{{title}}'>"] {
    let rejected = try {
      @moonpress.template_sources(html) |> ignore
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}
