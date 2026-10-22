///|
test "canonical UTC schedule calendar and exact boundaries" {
  assert_eq(publication_timestamp("1970-01-01T00:00:00Z"), 0L)
  assert_eq(publication_timestamp("2000-01-01T00:00:00Z"), 946684800L)
  assert_eq(publication_timestamp("1969-12-31T23:59:59Z"), -1L)
  assert_eq(
    publication_timestamp("2000-03-01T00:00:00Z") -
    publication_timestamp("2000-02-28T00:00:00Z"),
    172800L,
  )
  let timestamp = "2026-12-01T09:00:00Z"
  let instant = publication_timestamp(timestamp)
  assert_false(publication_due(Some(timestamp), instant - 1L))
  assert_true(publication_due(Some(timestamp), instant))
  assert_true(publication_due(None, instant))
  for
    bad in [
      "2026-02-29T00:00:00Z", "1900-02-29T00:00:00Z", "0000-01-01T00:00:00Z", "2026-01-01T24:00:00Z",
      "2026-01-01T00:60:00Z", "2026-01-01T00:00:60Z", "2026-01-01T00:00:00+09:00",
      "2026-01-01 00:00:00Z", "2026-01-01T00:00:00.0Z", "2026-01-01T00:00:00z",
    ] {
    let mut rejected = false
    try publication_timestamp(bad) |> ignore catch {
      _ => rejected = true
    }
    assert_true(rejected)
  }
}

///|
test "schedule metadata strictness" {
  let document = parse_document(
    "---\n{\"publish_at\":\"2026-12-01T09:00:00Z\"}\n---\n# Body", "post",
  )
  assert_eq(document.publish_at, Some("2026-12-01T09:00:00Z"))
  for value in ["true", "null", "1", "\"invalid\""] {
    let mut rejected = false
    try
      parse_document("---\n{\"publish_at\":" + value + "}\n---\n# Body", "post")
      |> ignore
    catch {
      _ => rejected = true
    }
    assert_true(rejected)
  }
}

///|
test "one explicit clock controls complete plan and reviewed identity" {
  if @env.get_env_var("MOONPRESS_SCHEDULE_SITE") is Some(site) {
    let before = plan_site(
      site,
      Map([]),
      None,
      publication_time=Some(publication_timestamp("2030-01-01T00:00:00Z") - 1L),
    )
    let after = plan_site(
      site,
      Map([]),
      None,
      publication_time=Some(publication_timestamp("2030-01-01T00:00:00Z")),
    )
    assert_eq(after.report.pages, before.report.pages + 1)
    assert_false(before.manifest == after.manifest)
    assert_false(
      review_identity(
        site,
        "output",
        false,
        before.manifest,
        describe_plan(before, Map([])),
      ) ==
      review_identity(
        site,
        "output",
        false,
        after.manifest,
        describe_plan(after, Map([])),
      ),
    )
    let preview = plan_site(
      site,
      Map([]),
      None,
      include_drafts=true,
      publication_time=Some(0L),
    )
    assert_true(preview.report.pages > after.report.pages)
  }
}
