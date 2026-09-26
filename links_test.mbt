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
