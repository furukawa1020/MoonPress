///|
fn test_heading_targets() -> Map[String, Map[String, Bool]] {
  let targets : Map[String, Map[String, Bool]] = Map([])
  targets["index.html"] = index_heading_ids(headings("# Home"))
  targets["guide.html"] = index_heading_ids(
    headings("# Guide\n## Repeat\n## Repeat\n## Repeat-2\n## 月🌙"),
  )
  targets["articles.html"] = Map([])
  targets
}

///|
test "heading links share route and Unicode percent normalization" {
  validate_heading_links(
    [
      "#mp-home", "?at=12:30#mp-home", "./#mp-home", "/MoonPress/#mp-home", "%67uide%2ehtml#%6dp-guide",
      "guide.html#mp-repeat-2", "guide.html#mp-repeat-2-2", "guide.html?q=1#mp-月🌙",
      "/MoonPress/guide.html#mp-%e6%9c%88%f0%9f%8c%99",
    ],
    test_heading_targets(),
    "index.html",
    "/MoonPress/",
    "index.html",
  )
}

///|
test "heading validation rejects missing IDs including empty collections" {
  for
    href in [
      "#mp-missing", "guide.html#mp-repeat-3", "articles.html#mp-guide", "guide.html#mp-%25",
      "#mp-%GG",
    ] {
    let rejected = try {
      validate_heading_links(
        [href],
        test_heading_targets(),
        "index.html",
        "/",
        "index.html",
      )
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
test "custom anchors external URLs and asset fragments remain out of scope" {
  validate_heading_links(
    [
      "#", "#custom", "guide.html#custom", "image.svg#mp-symbol", "image.svg#%broken",
      "HTTPS://example.org/#mp-missing", "https://example.org/#%bad", "MAILTO:a@b#mp-missing",
    ],
    test_heading_targets(),
    "index.html",
    "/",
    "index.html",
  )
}
