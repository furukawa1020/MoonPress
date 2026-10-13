///|
test "dependency changes report all deltas without mutating inputs" {
  let a = digest_text("a")
  let b = digest_text("b")
  let old : Array[Dependency] = [
    { name: "gone", digest: a, },
    { name: "same", digest: a, },
    { name: "edit", digest: a, },
  ]
  let next : Array[Dependency] = [
    { name: "same", digest: a, },
    { name: "edit", digest: b, },
    { name: "new", digest: b, },
  ]
  let changes = dependency_changes(old, next)
  assert_eq(changes.length(), 3)
  assert_true(
    changes.any(c => {
      c.name == "gone" && c.action == "removed" && c.new_digest is None
    }),
  )
  assert_true(
    changes.any(c => {
      c.name == "new" && c.action == "added" && c.old_digest is None
    }),
  )
  assert_true(
    changes.any(c => {
      c.name == "edit" && c.old_digest == Some(a) && c.new_digest == Some(b)
    }),
  )
  assert_eq(old[0].name, "gone")
  assert_eq(dependency_changes(old, [old[2], old[1], old[0]]).length(), 0)
  assert_eq(dependency_changes([], []).length(), 0)
}

///|
test "dependency changes reject ambiguous or malformed input" {
  let d = digest_text("a")
  for
    deps in [
      [{ name: "", digest: d, }],
      [{ name: "a", digest: "bad", }],
      [{ name: "a", digest: d, }, { name: "a", digest: d, }],
    ] {
    let rejected = try {
      let _ = dependency_changes([], deps)
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}
