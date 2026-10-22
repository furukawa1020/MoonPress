///|
test "revision IDs reject aliases and invalid digests" {
  let id = record_id("月.md", digest_text("text"))
  require_record_id(id)
  for bad in ["../x", "x.json", "", id + "x", record_id("a.md", "not-a-digest")] {
    assert_true(
      try {
        require_record_id(bad)
        false
      } catch {
        _ => true
      },
    )
  }
}

///|
test "immutable checkpoint filesystem probe" {
  guard @env.get_env_var("MOONPRESS_HISTORY_FIXTURE") is Some(input) else {
    return
  }
  enable_post_history(input) |> ignore
  let source = read_post(input, "a.md")
  let first = checkpoint_post(input, "a.md", source.digest)
  let second = checkpoint_post(input, "a.md", source.digest)
  assert_eq(first.id, second.id)
  assert_eq(list_post_revisions(input, "a.md").length(), 1)
  let record = read_post_revision(input, first.id)
  assert_eq(record.content, source.content)
  assert_eq(read_post(input, "a.md").digest, source.digest)
  assert_true(
    try {
      checkpoint_post(input, "a.md", digest_text("stale")) |> ignore
      false
    } catch {
      _ => true
    },
  )
  let vault = open_authoring_subdirectory(input, ".moonpress-history")
  defer directory_close(vault.fd)
  assert_true(
    try {
      store_authoring_record(vault, "a.md", String::make(4194305, 'x'))
      |> ignore
      false
    } catch {
      _ => true
    },
  )
}
