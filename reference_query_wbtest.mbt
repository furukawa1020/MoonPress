///|
test "redirect reference evidence must match its originating route" {
  let base = query_fixture()
  let redirect : RouteInfo = {
    name: "old.html",
    kind: "redirect",
    source: Some("site.json/redirects/old.html"),
    target: Some("a.html"),
  }
  let edge : ReferenceEdge = {
    source: "site.json/redirects/old.html",
    output: "old.html",
    kind: "redirect",
    url: "a.html",
    target: "a.html",
    fragment: None,
  }
  let graph : ReferenceGraph = {
    ..base,
    routes: [base.routes[0], base.routes[1], redirect],
    references: [edge],
  }
  assert_eq(query_references(graph, "old.html").outgoing.length(), 1)
  for
    invalid in [
      { ..edge, target: "月.html", },
      { ..edge, output: "a.html", },
      { ..edge, fragment: Some("mp-x"), },
      { ..edge, kind: "markdown-link", },
    ] {
    let failed = try {
      query_references({ ..graph, references: [invalid], }, "old.html")
      |> ignore
      false
    } catch {
      _ => true
    }
    assert_true(failed)
  }
}

///|
fn query_fixture() -> ReferenceGraph {
  let a : ReferenceEdge = {
    source: "content/a.md",
    output: "a.html",
    kind: "markdown-link",
    url: "月.html#mp-title",
    target: "月.html",
    fragment: Some("mp-title"),
  }
  let self : ReferenceEdge = {
    ..a,
    output: "月.html",
    source: "content/b.md",
    url: "#mp-title",
  }
  {
    pages: 2,
    include_drafts: true,
    routes: [
      {
        name: "月.html",
        kind: "page",
        source: Some("content/b.md"),
        target: None,
      },
      {
        name: "a.html",
        kind: "page",
        source: Some("content/a.md"),
        target: None,
      },
    ],
    references: [self, a, a],
    scope: reference_scope(),
  }
}

///|
test "reference query deduplicates both directions and preserves input" {
  let graph = query_fixture()
  let report = query_references(graph, "月.html")
  assert_eq(report.incoming.length(), 2)
  assert_eq(report.outgoing.length(), 1)
  assert_eq(report.route.source, Some("content/b.md"))
  assert_true(report.include_drafts)
  assert_eq(graph.references.length(), 3)
  assert_eq(graph.references[0].source, "content/b.md")
  assert_eq(query_references(graph, "a.html").incoming.length(), 0)
}

///|
test "reference query refuses unknown encoded names and malformed graphs" {
  let graph = query_fixture()
  for
    name in [
      "", "../a.html", "missing.html", "%E6%9C%88.html", "月.html#mp-title",
    ] {
    let failed = try {
      query_references(graph, name) |> ignore
      false
    } catch {
      _ => true
    }
    assert_true(failed)
  }
  for
    invalid in [
      { ..graph, pages: -1, },
      { ..graph, routes: [graph.routes[0], graph.routes[0]], },
      {
        ..graph,
        references: [{ ..graph.references[0], target: "missing.html", }],
      },
      { ..graph, references: [{ ..graph.references[0], kind: "unknown", }], },
    ] {
    let failed = try {
      query_references(invalid, "月.html") |> ignore
      false
    } catch {
      _ => true
    }
    assert_true(failed)
  }
}

///|
test "reference origins must agree with route kind and source" {
  let graph = query_fixture()
  let edge = graph.references[1]
  for kind in ["asset", "marker", "feed", "sitemap", "archive"] {
    let route = { ..graph.routes[1], kind, }
    let invalid = {
      ..graph,
      pages: 1,
      routes: [graph.routes[0], route],
      references: [edge],
    }
    assert_true(
      try {
        query_references(invalid, "a.html") |> ignore
        false
      } catch {
        _ => true
      },
    )
    if kind != "archive" {
      assert_true(
        try {
          query_references(
            {
              ..invalid,
              references: [
                { ..edge, kind: "template-href", source: "layout.html", },
              ],
            },
            "a.html",
          )
          |> ignore
          false
        } catch {
          _ => true
        },
      )
    }
  }
  assert_true(
    try {
      query_references(
        { ..graph, references: [{ ..edge, source: "content/other.md", }], },
        "a.html",
      )
      |> ignore
      false
    } catch {
      _ => true
    },
  )
}

///|
test "reference redirect targets must already be terminal" {
  let graph = query_fixture()
  let redirect : RouteInfo = {
    name: "old.html",
    kind: "redirect",
    source: None,
    target: Some("old.html"),
  }
  assert_true(
    try {
      query_references(
        { ..graph, routes: [..graph.routes, redirect], },
        "a.html",
      )
      |> ignore
      false
    } catch {
      _ => true
    },
  )
}
