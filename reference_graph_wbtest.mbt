///|
test "reference edges resolve encoded names self links queries and opaque asset fragments" {
  let routes : Map[String, String] = Map([
    ("index.html", "index.html"),
    (url_component("月.html"), "月.html"),
    ("photo.svg", "photo.svg"),
  ])
  let edges : Array[ReferenceEdge] = []
  append_reference_edges(
    edges,
    [
      "/demo/" + url_component("月.html") + "?q=1#mp-x",
      "#mp-home",
      "https://example.org",
      "photo.svg#%bad%",
    ],
    "content/index.md",
    "index.html",
    "markdown-link",
    routes,
    "/demo/",
  )
  assert_eq(edges.length(), 3)
  assert_eq(edges[0].target, "月.html")
  assert_eq(edges[0].fragment, Some("mp-x"))
  assert_eq(edges[1].target, "index.html")
  assert_eq(edges[2].fragment, Some("%bad%"))
  let sorted = sorted_reference_edges([edges[2], edges[0], edges[0], edges[1]])
  assert_eq(sorted.length(), 3)
  assert_true(sorted == sorted_reference_edges(edges))
  assert_eq(edges[0].target, "月.html")
}

///|
test "reference graph filesystem probe" {
  if @env.get_env_var("MOONPRESS_REFERENCE_PROBE") is Some(input) {
    let graph = inspect_references(input)
    assert_eq(graph.pages, 2)
    assert_false(graph.references.any(e => e.source == "content/draft.md"))
    assert_true(
      graph.references.any(e => {
        e.source == "content/index.md" &&
        e.target == "月.html" &&
        e.fragment == Some("mp-target")
      }),
    )
    assert_true(
      graph.references.any(e => {
        e.output == "月.html" &&
        e.source == "layouts/post.html" &&
        e.kind == "template-src"
      }),
    )
    assert_false(
      graph.references.any(e => {
        e.output == "old.html" && e.kind.has_prefix("template-")
      }),
    )
    assert_true(
      graph.references.any(e => {
        e.output == "old.html" && e.target == "月.html" && e.kind == "redirect"
      }),
    )
    assert_false(
      graph.references.any(e => {
        e.url.contains("example.org") || e.url == "absent.html"
      }),
    )
    let preview = inspect_references(input, include_drafts=true)
    assert_eq(preview.pages, 3)
    assert_true(
      preview.references.any(e => {
        e.source == "content/draft.md" && e.target == "index.html"
      }),
    )
    assert_eq(graph.to_json(), inspect_references(input).to_json())
  }
}
