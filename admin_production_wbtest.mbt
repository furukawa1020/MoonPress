///|
test "production plan escapes untrusted event fields" {
  let report : BuildReport = {
    pages: 1,
    written: 1,
    skipped: 0,
    deleted: 0,
    events: [],
    changes: [
      { action: "<write>", path: "</code><script>x</script>", reason: "\"<&'", },
    ],
  }
  let html = admin_production_changes(report)
  assert_true(html.contains("&lt;write&gt;"))
  assert_true(html.contains("&lt;/code&gt;&lt;script&gt;x&lt;/script&gt;"))
  assert_true(html.contains("&quot;&lt;&amp;&#39;"))
  assert_false(html.contains("<script>"))
}

///|
test "review distinguishes byte changes recomputation restoration and removal" {
  let item : PlannedOutput = {
    name: "a.html",
    action: "write",
    reason: "dependency changed",
    old_digest: Some("old"),
    new_digest: Some("new"),
    dependencies: [],
  }
  assert_eq(admin_output_effect(item), "Replace changed output bytes")
  assert_eq(
    admin_output_effect({ ..item, old_digest: None, }),
    "Create new output",
  )
  assert_eq(
    admin_output_effect({ ..item, action: "delete", }),
    "Remove generated output",
  )
  assert_eq(
    admin_output_effect({ ..item, action: "keep", }),
    "Keep existing output",
  )
  assert_eq(
    admin_output_effect({ ..item, new_digest: Some("old"), }),
    "Recompute; bytes unchanged",
  )
  assert_eq(
    admin_output_effect({
      ..item,
      reason: "output missing",
      new_digest: Some("old"),
    }),
    "Restore missing output",
  )
}

///|
test "dependency review escapes all fields and separates excluded drafts" {
  let plan : DetailedBuildPlan = {
    summary: {
      pages: 1,
      written: 1,
      skipped: 0,
      deleted: 0,
      events: [],
      changes: [
        { action: "skip", path: "content/<draft>.md", reason: "<excluded>", },
      ],
    },
    outputs: [
      {
        name: "<page>.html",
        action: "write",
        reason: "<reason>",
        old_digest: Some("<old>"),
        new_digest: Some("<new>"),
        dependencies: [
          {
            name: "<source>",
            action: "<changed>",
            old_digest: Some("<before>"),
            new_digest: Some("<after>"),
          },
        ],
      },
    ],
  }
  let html = admin_dependency_review(plan)
  for
    value in [
      "page", "reason", "source", "changed", "old", "new", "before", "after", "draft",
      "excluded",
    ] {
    assert_true(html.contains("&lt;" + value + "&gt;"))
    assert_false(html.contains("<" + value + ">"))
  }
  assert_true(
    html.contains("<details><summary>Inspect observed SHA-256 digests"),
  )
  assert_true(html.contains("Drafts excluded from production"))
}
