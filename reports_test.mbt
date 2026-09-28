///|
test "build report JSON preserves structured Unicode events" {
  let event : @moonpress.BuildEvent = {
    action: "write",
    path: "月\".html",
    reason: "changed dependency: content/月\".md",
  }
  let report : @moonpress.BuildReport = {
    pages: 1,
    written: 1,
    skipped: 0,
    deleted: 0,
    events: ["WRITE 月\".html — changed dependency: content/月\".md"],
    changes: [event],
  }
  let json = report.to_json()
  let expected : Json = {
    "pages": 1,
    "written": 1,
    "skipped": 0,
    "deleted": 0,
    "events": ["WRITE 月\".html — changed dependency: content/月\".md"],
    "changes": [
      {
        "action": "write",
        "path": "月\".html",
        "reason": "changed dependency: content/月\".md",
      },
    ],
  }
  assert_eq(json, expected)
  assert_true(json.stringify().contains("\\\".html"))
}

///|
test "check report JSON contains planned counts only" {
  let report : @moonpress.CheckReport = { pages: 2, outputs: 6, }
  let expected : Json = { "pages": 2, "outputs": 6 }
  assert_eq(report.to_json(), expected)
}
