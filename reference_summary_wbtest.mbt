///|
test "reference summary counts evidence once and separates self from other outputs" {
  let graph = query_fixture()
  let second = {
    ..graph.references[1],
    url: "月.html?view=2",
    fragment: None,
  }
  let isolated : RouteInfo = {
    name: "unused.svg",
    kind: "asset",
    source: Some("public/unused.svg"),
    target: None,
  }
  let enriched = {
    ..graph,
    references: [..graph.references, second],
    routes: [isolated, ..graph.routes],
  }
  let report = summarize_references(enriched)
  assert_eq(report.edges, 3)
  assert_eq(report.pages, 2)
  assert_true(report.include_drafts)
  let a = report.routes.filter(row => row.route.name == "a.html")[0]
  let unused = report.routes.filter(row => row.route.name == "unused.svg")[0]
  let target = report.routes.filter(row => row.route.name == "月.html")[0]
  assert_eq(
    report.routes.map(row => row.route.name),
    sorted_routes(enriched.routes).map(route => route.name),
  )
  assert_eq(a.outgoing, 2)
  assert_eq(unused.route.name, "unused.svg")
  assert_eq(unused.incoming, 0)
  assert_eq(unused.referring_outputs, 0)
  assert_eq(target.incoming, 3)
  assert_eq(target.outgoing, 1)
  assert_eq(target.self_references, 1)
  assert_eq(target.referring_outputs, 1)
  assert_eq(enriched.routes[0].name, "unused.svg")
  assert_eq(enriched.references.length(), 4)
  for row in report.routes {
    let query = query_references(enriched, row.route.name)
    assert_eq(row.incoming, query.incoming.length())
    assert_eq(row.outgoing, query.outgoing.length())
  }
}

///|
test "summary handles empty edges self-only and redirect referrers" {
  let base = query_fixture()
  let empty = summarize_references({ ..base, references: [], })
  assert_eq(empty.edges, 0)
  assert_true(empty.routes.all(row => row.incoming == 0 && row.outgoing == 0))
  let self_only = summarize_references({
    ..base,
    references: [base.references[0]],
  })
  assert_eq(self_only.routes[1].self_references, 1)
  assert_eq(self_only.routes[1].referring_outputs, 0)
  let redirect : RouteInfo = {
    name: "old.html",
    kind: "redirect",
    source: None,
    target: Some("月.html"),
  }
  let edge : ReferenceEdge = {
    source: "site.json/redirects/old.html",
    output: "old.html",
    kind: "redirect",
    url: "%E6%9C%88.html",
    target: "月.html",
    fragment: None,
  }
  let report = summarize_references({
    ..base,
    routes: [..base.routes, redirect],
    references: [edge],
  })
  assert_eq(
    report.routes.filter(row => row.route.name == "old.html")[0].outgoing,
    1,
  )
  assert_eq(
    report.routes.filter(row => row.route.name == "月.html")[0].referring_outputs,
    1,
  )
}

///|
test "summary refuses malformed graphs even without queried routes" {
  let graph = query_fixture()
  assert_true(
    try {
      summarize_references({ ..graph, pages: 0, }) |> ignore
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      summarize_references({
        ..graph,
        references: [{ ..graph.references[0], target: "absent.html", }],
      })
      |> ignore
      false
    } catch {
      _ => true
    },
  )
}
