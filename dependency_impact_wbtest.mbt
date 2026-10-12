///|
test "impact deduplicates requests and preserves shared matches without mutating inputs" {
  let digest = digest_text("output")
  let graph : DependencyGraph = {
    pages: 2,
    include_drafts: true,
    artifacts: [
      { name: "b.html", digest, dependencies: [{ name: "compiler", digest, }], },
      {
        name: "a.html",
        digest,
        dependencies: [
          { name: "content/a.md", digest, },
          { name: "compiler", digest, },
        ],
      },
    ],
  }
  let names = ["compiler", "content/a.md", "missing", "compiler"]
  let report = dependency_impact(graph, names)
  assert_true(report.include_drafts)
  assert_eq(report.requested.length(), 3)
  assert_eq(report.unknown, ["missing"])
  assert_eq(report.outputs.length(), 2)
  assert_eq(report.outputs[0].name, "a.html")
  assert_eq(report.outputs[0].dependencies.length(), 2)
  assert_eq(report.outputs[1].dependencies, ["compiler"])
  assert_eq(report.outputs[0].digest, digest)
  assert_eq(names.length(), 4)
  assert_eq(graph.artifacts[0].name, "b.html")
}

///|
test "impact matches exact keys and explicitly reports unknown requests" {
  let digest = digest_text("output")
  let graph : DependencyGraph = {
    pages: 0,
    include_drafts: false,
    artifacts: [
      {
        name: "index.html",
        digest,
        dependencies: [{ name: "collection", digest, }],
      },
    ],
  }
  let report = dependency_impact(graph, [
    "Collection", " collection", "content/a.md",
  ])
  assert_eq(report.unknown.length(), 3)
  assert_eq(report.outputs.length(), 0)
  assert_eq(
    dependency_impact({ ..graph, artifacts: [], }, ["collection"]).unknown,
    ["collection"],
  )
}

///|
test "impact rejects invalid requests and malformed externally constructed graphs" {
  let graph : DependencyGraph = {
    pages: 0,
    include_drafts: false,
    artifacts: [],
  }
  for names in [[], [""], ["valid", ""]] {
    let rejected = try {
      let _ = dependency_impact(graph, names)
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  let invalid : DependencyGraph = {
    ..graph,
    artifacts: [{ name: "../outside", digest: "bad", dependencies: [], }],
  }
  let rejected = try {
    let _ = dependency_impact(invalid, ["compiler"])
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}
