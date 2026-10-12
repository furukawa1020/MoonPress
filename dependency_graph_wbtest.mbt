///|
test "dependency graph sorting preserves caller arrays and exact digests" {
  let digest = digest_text("artifact")
  let artifacts : Array[Artifact] = [
    {
      name: "z.html",
      digest,
      dependencies: [{ name: "b", digest, }, { name: "a", digest, }],
    },
    { name: "a.html", digest, dependencies: [{ name: "a", digest, }], },
  ]
  let graph = graph_artifacts(artifacts)
  assert_eq(graph[0].name, "a.html")
  assert_eq(graph[1].dependencies[0].name, "a")
  assert_eq(graph[1].digest, digest)
  assert_eq(artifacts[0].name, "z.html")
  assert_eq(artifacts[0].dependencies[0].name, "b")
}

///|
test "shared and synthetic dependency edges are retained per output" {
  let digest = digest_text("shared")
  let artifacts : Array[Artifact] = [
    {
      name: "a.html",
      digest,
      dependencies: [
        { name: "compiler", digest, },
        { name: "content/a.md", digest, },
      ],
    },
    {
      name: "b.html",
      digest,
      dependencies: [
        { name: "compiler", digest, },
        { name: "collection", digest, },
      ],
    },
  ]
  let graph = graph_artifacts(artifacts)
  assert_eq(graph.length(), 2)
  assert_eq(graph[0].dependencies.length(), 2)
  assert_eq(graph[1].dependencies.length(), 2)
  assert_true(graph[1].dependencies.any(dep => dep.name == "collection"))
  assert_eq(graph_artifacts([]).length(), 0)
}
