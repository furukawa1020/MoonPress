///|
test "feed config preserves old config and rejects invalid shapes" {
  assert_true(
    parse_site_config("{\"base_url\":\"https://example.org\"}").feed is None,
  )
  for
    source in [
      "[]", "{\"base_url\":null}", "{\"base_url\":\"https://example.org\",\"feed\":true}",
      "{\"base_url\":\"https://example.org\",\"feed\":null}", "{\"base_url\":\"https://example.org\",\"feed\":{\"title\":\"x\"}}",
      "{\"base_url\":\"https://example.org\",\"feed\":{\"title\":\" \",\"description\":\"y\"}}",
      "{\"base_url\":\"https://example.org\",\"feed\":{\"title\":\"x\",\"description\":\"y\",\"typo\":1}}",
    ] {
    let rejected = try {
      let _ = parse_site_config(source)
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
test "RSS plain summaries use two escaping layers and stable absolute IDs" {
  let page : Page = {
    output: "月.html",
    document: parse_document(
      "---\n{\"title\":\"<Title>&\",\"description\":\"<script>&\",\"tags\":[\"a&b\"]}\n---\nBody",
      "fallback",
    ),
  }
  let feed : FeedConfig = {
    title: "News & 月",
    description: "Updates <here>",
  }
  let xml = render_feed("https://example.org/project/", feed, [page])
  assert_true(xml.contains("<title>News &amp; 月</title>"))
  assert_true(xml.contains("<description>Updates &lt;here&gt;</description>"))
  assert_true(xml.contains("<title>&lt;Title&gt;&amp;</title>"))
  assert_true(
    xml.contains("<description>&amp;lt;script&amp;gt;&amp;amp;</description>"),
  )
  assert_true(
    xml.contains(
      "<guid isPermaLink=\"true\">https://example.org/project/%E6%9C%88.html</guid>",
    ),
  )
  assert_true(xml.contains("<category>a&amp;b</category>"))
  assert_false(xml.contains("pubDate"))
  assert_false(xml.contains("Body"))
}

///|
test "XML characters reject forbidden control and noncharacters" {
  require_xml_text("月😀\t\r\n", "valid")
  for text in ["\u{0}", "\u{1}", "\u{b}", "\u{fffe}", "\u{ffff}"] {
    let rejected = try {
      require_xml_text(text, "test")
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}
