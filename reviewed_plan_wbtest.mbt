///|
test "review identity binds paths mode manifest and complete plan" {
  let summary : BuildReport = {
    pages: 0,
    written: 0,
    skipped: 0,
    deleted: 0,
    events: [],
    changes: [],
  }
  let detail : DetailedBuildPlan = { summary, outputs: [], }
  let id = review_identity("site", "out", false, "manifest", detail)
  assert_true(valid_digest(id))
  assert_eq(id, review_identity("site", "out", false, "manifest", detail))
  assert_true(id != review_identity("site/", "out", false, "manifest", detail))
  assert_true(id != review_identity("site", "out/", false, "manifest", detail))
  assert_true(id != review_identity("site", "out", true, "manifest", detail))
  assert_true(
    id != review_identity("site", "out", false, "changed dependency", detail),
  )
  let deleted : DetailedBuildPlan = {
    summary,
    outputs: [
      {
        name: "old.html",
        action: "delete",
        reason: "source removed",
        old_digest: Some(digest_text("old")),
        new_digest: None,
        dependencies: [],
      },
    ],
  }
  assert_true(id != review_identity("site", "out", false, "manifest", deleted))
  // JSON encoding must distinguish inputs containing separators and quotes.
  assert_true(
    review_identity("a\"b", "c", false, "", detail) !=
    review_identity("a", "b\"c", false, "", detail),
  )
}
