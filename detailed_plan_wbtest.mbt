///|
test "detailed plan preserves actual actions including missing output repair" {
  let a = digest_text("a")
  let b = digest_text("b")
  let dep : Dependency = { name: "content/a.md", digest: a, }
  let previous : Map[String, Artifact] = Map([
    ("gone.html", { name: "gone.html", digest: a, dependencies: [dep], }),
    ("edit.html", { name: "edit.html", digest: a, dependencies: [dep], }),
    ("keep.html", { name: "keep.html", digest: a, dependencies: [dep], }),
    ("missing.html", { name: "missing.html", digest: a, dependencies: [dep], }),
  ])
  let summary : BuildReport = {
    pages: 3,
    written: 2,
    skipped: 1,
    deleted: 1,
    events: [],
    changes: [
      { action: "skip", path: "content/draft.md", reason: "draft", },
      { action: "write", path: "missing.html", reason: "output missing", },
      {
        action: "write",
        path: "edit.html",
        reason: "changed dependency: content/a.md",
      },
      { action: "keep", path: "keep.html", reason: "dependencies unchanged", },
      { action: "delete", path: "gone.html", reason: "source removed", },
    ],
  }
  let plan : BuildPlan = {
    pending: [
      {
        artifact: {
          name: "edit.html",
          digest: b,
          dependencies: [{ name: dep.name, digest: b, }],
        },
        content: Some(b"b"),
      },
      { artifact: previous["keep.html"], content: None, },
      { artifact: previous["missing.html"], content: Some(b"a"), },
    ],
    removed: ["gone.html"],
    manifest: "",
    report: summary,
  }
  let detail = describe_plan(plan, previous)
  assert_eq(detail.summary.written, 2)
  assert_eq(detail.outputs.length(), 4)
  assert_eq(detail.summary.changes.length(), 5)
  assert_true(detail.outputs.all(o => o.name != "content/draft.md"))
  let repair = detail.outputs.filter(o => o.name == "missing.html")[0]
  assert_eq(repair.action, "write")
  assert_eq(repair.reason, "output missing")
  assert_eq(repair.dependencies.length(), 0)
  assert_eq(repair.old_digest, repair.new_digest)
  let edit = detail.outputs.filter(o => o.name == "edit.html")[0]
  assert_eq(edit.dependencies[0].action, "changed")
  let gone = detail.outputs.filter(o => o.name == "gone.html")[0]
  assert_eq(gone.new_digest, None)
  assert_eq(gone.dependencies[0].action, "removed")
  assert_eq(plan.report.changes[0].path, "content/draft.md")
}
