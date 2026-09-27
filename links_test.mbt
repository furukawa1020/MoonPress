///|
test "inline links and code" {
  assert_eq(
    @moonpress.render_inline("[月](guide.html) `<b>`"),
    "<a href=\"guide.html\">月</a> <code>&lt;b&gt;</code>",
  )
  assert_eq(
    @moonpress.markdown_links(
      "`[x](missing.html)`\n```\n[x](missing.html)\n```\n[x](ok.html)",
    ),
    ["ok.html"],
  )
  assert_false(@moonpress.render_inline("[x](javascript:alert)").contains("<a"))
}

///|
test "internal links preserve case and decode percent spelling" {
  @moonpress.validate_links(
    [
      "guide.html?q=1#intro", "%e6%9c%88.html", "/MoonPress/guide.html", "#intro",
      "https://example.org",
    ],
    ["guide.html", "月.html"],
    base_path="/MoonPress/",
  )
  for
    href in [
      "Guide.html", "missing.html", "../guide.html", "javascript:x", "//example.org",
      "bad%zz.html", "/other/guide.html",
    ] {
    let rejected = try {
      @moonpress.validate_links([href], ["guide.html"], base_path="/MoonPress/")
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
test "template href tokenizer respects attributes and comments" {
  assert_eq(
    @moonpress.template_links(
      "<!-- <a href=\"missing\"> -->\n<a title=\"href='fake' >\" HREF = 'guide.html?a=1&amp;b=2'>x</a>",
    ),
    ["guide.html?a=1&b=2"],
  )
}

///|
test "sitemap uses normalized base and escaped Unicode URL" {
  let base = @moonpress.normalize_base_url("https://example.org/MoonPress")
  assert_eq(base, "https://example.org/MoonPress/")
  assert_eq(@moonpress.site_base_path(base), "/MoonPress/")
  let xml = @moonpress.render_sitemap(base, ["月.html", "style.css"])
  assert_true(xml.contains("https://example.org/MoonPress/%E6%9C%88.html"))
  assert_false(xml.contains("style.css"))
  for
    invalid in [
      "ftp://host", "https:///path", "https://host/a/../b", "https://host/?x", "https://user@host",
    ] {
    let rejected = try {
      @moonpress.normalize_base_url(invalid) |> ignore
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
test "unreserved percent encodings identify the same route" {
  @moonpress.validate_links(
    ["%67uide%2ehtml", "%7e%2D%5f%41.html", "%e6%9c%88.html"],
    ["guide.html", "~-_A.html", "月.html"],
  )
  for
    href in [
      "%", "%G0", "guide%2F.html", "%2e%2e%2Fguide.html", "%00guide.html", "%2567uide.html",
    ] {
    let rejected = try {
      @moonpress.validate_links([href], ["guide.html"])
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  // A percent sign in the literal filename is a different route.
  @moonpress.validate_links(["%2567uide.html"], ["%67uide.html"])
}

///|
test "scheme parsing does not bypass local checks through query colons" {
  @moonpress.validate_links(
    [
      "guide.html?at=12:30#note:x", "#note:x", "HTTPS://example.org", "MAILTO:x@y",
    ],
    ["guide.html"],
  )
  @moonpress.validate_sources(["HTTP://example.org/x.png", "x.png?q=12:30"], [
    "x.png",
  ])
  for
    href in [
      "missing.html?q=https://example.org", "missing.html#note:x", "JaVaScRiPt:x",
      "data:x",
    ] {
    let rejected = try {
      @moonpress.validate_links([href], ["guide.html"])
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  let rejected = try {
    @moonpress.validate_sources(["MAILTO:x@y"], [])
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}
