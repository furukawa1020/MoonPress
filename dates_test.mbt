///|
fn dated_page(output : String, date : String?) -> @moonpress.Page raise {
  let header = match date {
    None => "{}"
    Some(value) => "{\"date\":\"" + value + "\"}"
  }
  {
    output,
    document: @moonpress.parse_document(
      "---\n" + header + "\n---\n# Page",
      "fallback",
    ),
  }
}

///|
test "publication dates accept strict Gregorian dates without scheduling" {
  assert_eq(@moonpress.parse_document("# Page", "x").date, None)
  for
    value in [
      "0001-01-01", "2000-02-29", "2024-02-29", "1900-02-28", "2026-04-30", "9999-12-31",
    ] {
    assert_eq(dated_page("a.html", Some(value)).document.date, Some(value))
  }
}

///|
test "publication dates reject impossible calendars formats and metadata types" {
  for
    value in [
      "0000-01-01", "1900-02-29", "2100-02-29", "2026-02-29", "2026-04-31", "2026-00-10",
      "2026-13-01", "2026-01-00", "2026-01-32", "2026-1-01", "2026-01-1", "2026/01/01",
      " 2026-01-01", "2026-01-01T00:00:00Z", "２０２６-01-01", "10000-01-01",
      "", "xxxx-yy-zz",
    ] {
    try dated_page("a.html", Some(value)) catch {
      _ => ()
    } noraise {
      _ => fail("expected invalid date: " + value)
    }
  }
  for value in ["null", "42", "true", "[]"] {
    try
      @moonpress.parse_document(
        "---\n{\"draft\":true,\"date\":" + value + "}\n---\n# Draft",
        "x",
      )
    catch {
      _ => ()
    } noraise {
      _ => fail("expected invalid date type")
    }
  }
}

///|
test "collections sort dates newest first then filename without mutating input" {
  let pages = [
    dated_page("aa.html", None),
    dated_page("old.html", Some("2020-01-01")),
    dated_page("bb.html", Some("2026-01-01")),
    dated_page("z.html", None),
    dated_page("a.html", Some("2026-01-01")),
  ]
  let before = pages.map(p => p.output)
  let html = @moonpress.render_collection("Articles", pages)
  let order = ["a.html", "bb.html", "old.html", "z.html", "aa.html"]
  for i = 0; i < order.length() - 1; i = i + 1 {
    assert_true(
      html.find("href=\"" + order[i] + "\"").unwrap() <
      html.find("href=\"" + order[i + 1] + "\"").unwrap(),
    )
  }
  assert_eq(pages.map(p => p.output), before)
  assert_true(html.contains("<time datetime=\"2026-01-01\">2026-01-01</time>"))
}

///|
test "date layout substitution is escaped and single pass" {
  assert_eq(
    @moonpress.apply_layout(
      "{{date}}|{{content}}",
      "x",
      "body",
      date="<date>{{title}}",
    ),
    "&lt;date&gt;{{title}}|body",
  )
  assert_eq(
    @moonpress.apply_layout("{{date}}|{{content}}", "x", "body"),
    "|body",
  )
  let page : @moonpress.Page = {
    output: "a.html",
    document: {
      title: "A",
      description: "",
      tags: [],
      body: "",
      draft: false,
      listed: true,
      layout: None,
      slug: None,
      date: Some("\"><x>"),
    },
  }
  assert_true(
    @moonpress.render_collection("Articles", [page]).contains(
      "datetime=\"&quot;&gt;&lt;x&gt;\"",
    ),
  )
}

///|
test "date changes participate in collection metadata dependencies" {
  let a = dated_page("a.html", Some("2026-01-01"))
  let b = dated_page("a.html", Some("2026-01-02"))
  let c = dated_page("a.html", None)
  assert_true(@moonpress.metadata_digest(a) != @moonpress.metadata_digest(b))
  assert_true(@moonpress.metadata_digest(a) != @moonpress.metadata_digest(c))
}
