///|
test "heading anchors use visible text and Unicode" {
  let outline = @moonpress.headings(
    "# Hello [Moon](guide.html) `Bit` ![Logo](logo.svg)\n## 日本語 の 見出し\n```\n# Hidden\n```",
  )
  assert_eq(outline.length(), 2)
  assert_eq(outline[0].text, "Hello Moon Bit Logo")
  assert_eq(outline[0].id, "mp-hello-moon-bit-logo")
  assert_eq(outline[1].level, 2)
  assert_eq(outline[1].id, "mp-日本語-の-見出し")
  assert_true(
    @moonpress.render_markdown("## 日本語 の 見出し").contains(
      "id=\"mp-日本語-の-見出し\"",
    ),
  )
}

///|
test "duplicate and suffix-like headings never reuse IDs" {
  let source = "# Intro\n# Intro\n# Intro-2\n# Intro\n# !!!\n# ???\n# Section-2"
  assert_eq(@moonpress.headings(source).map(h => h.id), [
    "mp-intro", "mp-intro-2", "mp-intro-2-2", "mp-intro-3", "mp-section", "mp-section-2",
    "mp-section-2-2",
  ])
  assert_eq(@moonpress.headings("# Intro-2\n# Intro\n# Intro").map(h => h.id), [
    "mp-intro-2", "mp-intro", "mp-intro-3",
  ])
}

///|
test "anchor generation is deterministic and escapes heading markup" {
  let source = "# <img onerror=\"x\"> & 'quoted'\r\n## Upper_CASE\r\n"
  assert_eq(@moonpress.headings(source).map(h => h.id), [
    "mp-img-onerror-x-quoted", "mp-upper_case",
  ])
  let html = @moonpress.render_markdown(source)
  assert_true(html.contains("id=\"mp-img-onerror-x-quoted\""))
  assert_true(html.contains("&lt;img onerror=&quot;x&quot;&gt;"))
  assert_eq(@moonpress.headings(source)[1].id, "mp-upper_case")
}

///|
test "TOC uses the same unique IDs and plain escaped text" {
  let source = "# [Moon](guide.html) & `<x>`\n### 日本語\n# [Moon](guide.html) & `<x>`"
  let toc = @moonpress.render_toc(source)
  assert_true(toc.contains("href=\"#mp-moon-x\">Moon &amp; &lt;x&gt;</a>"))
  assert_true(toc.contains("class=\"toc-level-3\""))
  assert_true(toc.contains("href=\"#mp-%E6%97%A5%E6%9C%AC%E8%AA%9E\""))
  assert_true(toc.contains("href=\"#mp-moon-x-2\""))
  assert_false(toc.contains("href=\"guide.html\""))
  assert_eq(@moonpress.render_toc("Text\n```\n# Example\n```"), "")
}

///|
test "TOC layout expansion is optional and single-pass" {
  assert_eq(@moonpress.apply_layout("{{toc}}{{content}}", "T", "Body"), "Body")
  let toc = @moonpress.render_toc("# {{content}}")
  let result = @moonpress.apply_layout(
    "{{toc}}<main>{{content}}</main>",
    "T",
    "Body",
    toc~,
  )
  assert_true(result.contains(">{{content}}</a>"))
  assert_true(result.contains("<main>Body</main>"))
}
