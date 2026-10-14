///|
test "review gate rejects invalid or stale IDs" {
  let current = digest_text("current")
  require_review(current, current)
  for invalid in ["", "abc", current.to_upper(), digest_text("stale")] {
    let rejected = try {
      require_review(invalid, current)
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
test "reviewed publication filesystem probe" {
  if @env.get_env_var("MOONPRESS_REVIEW_PROBE") is Some(root) {
    let input = root + "/site"
    let output = root + "/out"
    init_site(input) |> ignore
    let review = review_build_plan(input, output)
    assert_eq(path_kind(output), 0)
    assert_eq(review.review_id, review_build_plan(input, output).review_id)
    write_text(input + "/content/index.md", "# Changed\n")
    let rejected = try {
      compile_reviewed_site(input, output, review.review_id) |> ignore
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
    assert_eq(path_kind(output), 0)
    let fresh = review_build_plan(input, output)
    let report = compile_reviewed_site(input, output, fresh.review_id)
    assert_eq(report.to_json(), fresh.plan.summary.to_json())
    let snapshot = read_text(output + "/.moonpress.json")
    let replay_rejected = try {
      compile_reviewed_site(input, output, fresh.review_id) |> ignore
      false
    } catch {
      _ => true
    }
    assert_true(replay_rejected)
    assert_eq(snapshot, read_text(output + "/.moonpress.json"))
    let noop = review_build_plan(input, output)
    assert_eq(compile_reviewed_site(input, output, noop.review_id).written, 0)
  }
}
