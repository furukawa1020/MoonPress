///|
test "output reference summary escapes names and encodes inspection links" {
  let route : RouteInfo = {
    name: "a&月.html",
    kind: "<kind>",
    source: None,
    target: None,
  }
  let row : RouteReferenceCount = {
    route,
    incoming: 2,
    outgoing: 3,
    self_references: 1,
    referring_outputs: 1,
  }
  let report : ReferenceSummary = {
    pages: 1,
    include_drafts: true,
    edges: 4,
    routes: [row],
    scope: "",
  }
  let html = admin_reference_summary_table(report, "all", 1)
  assert_true(html.contains("a&amp;月.html"))
  assert_true(html.contains("&lt;kind&gt;"))
  assert_true(html.contains("scope=all&amp;output=a%26%E6%9C%88.html"))
  assert_false(html.contains("href=\"a&"))
  assert_true(html.contains("<td>2</td><td>3</td><td>1</td><td>1</td>"))
  assert_true(html.contains("Zero counts do not prove deletion safety"))
}

///|
test "output reference pagination retains scope and bounds rows" {
  let rows : Array[RouteReferenceCount] = []
  for i = 0; i < 21; i = i + 1 {
    rows.push({
      route: {
        name: "route\{i}.html",
        kind: "page",
        source: None,
        target: None,
      },
      incoming: 0,
      outgoing: 0,
      self_references: 0,
      referring_outputs: 0,
    })
  }
  let report : ReferenceSummary = {
    pages: 21,
    include_drafts: true,
    edges: 0,
    routes: rows,
    scope: "",
  }
  let first = admin_reference_summary_table(report, "all", 1)
  assert_true(first.contains("scope=all&amp;page=2"))
  assert_false(first.contains(">route20.html</a>"))
  let second = admin_reference_summary_table(report, "all", 2)
  assert_true(second.contains("scope=all&amp;page=1"))
  assert_true(second.contains(">route20.html</a>"))
  assert_false(second.contains(">route19.html</a>"))
  assert_true(
    try {
      admin_reference_summary_table(report, "all", 3) |> ignore
      false
    } catch {
      _ => true
    },
  )
}
