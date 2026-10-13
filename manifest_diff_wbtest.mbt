///|
test "manifest comparison distinguishes content and dependency changes" {
  let a = digest_text("a")
  let b = digest_text("b")
  let dep : Dependency = { name: "source", digest: a, }
  let old : Array[Artifact] = [
    { name: "gone.html", digest: a, dependencies: [dep], },
    { name: "content.html", digest: a, dependencies: [dep], },
    { name: "deps.html", digest: a, dependencies: [dep], },
    { name: "same.html", digest: a, dependencies: [dep], },
  ]
  let next : Array[Artifact] = [
    { name: "same.html", digest: a, dependencies: [dep], },
    {
      name: "deps.html",
      digest: a,
      dependencies: [{ name: "other", digest: b, }],
    },
    { name: "content.html", digest: b, dependencies: [dep], },
    { name: "new.html", digest: b, dependencies: [], },
  ]
  let report = compare_manifests(
    serialize_manifest(old),
    serialize_manifest(next),
  )
  assert_eq(report.added, 1)
  assert_eq(report.removed, 1)
  assert_eq(report.changed, 2)
  assert_eq(report.unchanged, 1)
  let dependencies = report.outputs.filter(o => o.name == "deps.html")[0]
  assert_true(!dependencies.content_changed)
  assert_eq(dependencies.dependencies.length(), 2)
  let content = report.outputs.filter(o => o.name == "content.html")[0]
  assert_true(content.content_changed)
  assert_eq(content.dependencies.length(), 0)
  let gone = report.outputs.filter(o => o.name == "gone.html")[0]
  assert_eq(gone.new_digest, None)
  assert_eq(gone.dependencies[0].action, "removed")
  assert_eq(old[0].name, "gone.html")
  let reversed = compare_manifests(
    serialize_manifest(next),
    serialize_manifest(old),
  )
  assert_eq(reversed.added, report.removed)
  assert_eq(reversed.changed, report.changed)
  assert_eq(
    compare_manifests(serialize_manifest([]), serialize_manifest([])).outputs.length(),
    0,
  )
}

///|
test "manifest comparison ignores ordering and validates both inputs" {
  let d = digest_text("d")
  let a : Dependency = { name: "a", digest: d, }
  let b : Dependency = { name: "b", digest: d, }
  let old = serialize_manifest([
    { name: "a.html", digest: d, dependencies: [a, b], },
  ])
  let next = serialize_manifest([
    { name: "a.html", digest: d, dependencies: [b, a], },
  ])
  assert_eq(compare_manifests(old, next).unchanged, 1)
  for
    bad in [
      "{}",
      serialize_manifest([{ name: "../bad", digest: d, dependencies: [], }]),
      serialize_manifest([{ name: "a", digest: "bad", dependencies: [], }]),
    ] {
    assert_true(
      try {
        let _ = compare_manifests(bad, old)
        false
      } catch {
        _ => true
      },
    )
    assert_true(
      try {
        let _ = compare_manifests(old, bad)
        false
      } catch {
        _ => true
      },
    )
  }
}
