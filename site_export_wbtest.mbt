///|
test "verified production export filesystem probe" {
  guard @env.get_env_var("MOONPRESS_EXPORT_PROBE") is Some(root) else { return }
  let input = root + "/site"
  let output = root + "/out"
  init_site(input) |> ignore
  write_text(
    input + "/content/private.md",
    "---\n{\"draft\": true}\n---\n# Private\n",
  )
  write_text(input + "/content/月.md", "# 月\n")
  compile_site(input, output) |> ignore
  let id = review_build_plan(input, output).review_id
  let manifest = read_bytes(output + "/.moonpress.json")
  let exported = export_site(input, output, id)
  assert_true(!exported.report.files.contains(".moonpress.json"))
  assert_true(!exported.report.files.contains("private.html"))
  assert_true(exported.report.files.contains("月.html"))
  assert_eq(exported.report.bytes, exported.content.length())
  assert_eq(exported.report.digest, digest_bytes(exported.content))
  assert_eq(exported.content, export_site(input, output, id).content)
  write_bytes(root + "/site.zip", exported.content)
  for invalid in ["bad", digest_text("stale")] {
    assert_true(
      try {
        export_site(input, output, invalid) |> ignore
        false
      } catch {
        _ => true
      },
    )
  }
  write_text(input + "/content/index.md", "# Changed\n")
  let changed_id = review_build_plan(input, output).review_id
  for stale in [id, changed_id] {
    assert_true(
      try {
        export_site(input, output, stale) |> ignore
        false
      } catch {
        _ => true
      },
    )
  }
  assert_eq(manifest, read_bytes(output + "/.moonpress.json"))
  compile_site(input, output, include_drafts=true) |> ignore
  let draft_id = review_build_plan(input, output).review_id
  assert_true(
    try {
      export_site(input, output, draft_id) |> ignore
      false
    } catch {
      _ => true
    },
  )
  compile_site(input, output) |> ignore
  let current = review_build_plan(input, output).review_id
  write_text(output + "/index.html", "edited")
  assert_true(
    try {
      export_site(input, output, current) |> ignore
      false
    } catch {
      _ => true
    },
  )
  assert_eq(read_text(output + "/index.html"), "edited")
}
