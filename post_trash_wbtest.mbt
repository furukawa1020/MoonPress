///|
test "article trash and restoration filesystem probe" {
  guard @env.get_env_var("MOONPRESS_TRASH_FIXTURE") is Some(input) else {
    return
  }
  let before = read_post(input, "a.md")
  assert_true(
    try {
      trash_post(input, "a.md", digest_text("stale")) |> ignore
      false
    } catch {
      _ => true
    },
  )
  let item = trash_post(input, "a.md", before.digest)
  assert_eq(path_kind(input + "/content/a.md"), 0)
  assert_eq(list_trashed_posts(input).length(), 1)
  assert_eq(read_trashed_post(input, item.id).content, before.content)
  assert_true(
    try {
      restore_trashed_post(input, item.id, digest_text("stale")) |> ignore
      false
    } catch {
      _ => true
    },
  )
  let directory = open_authoring_subdirectory(input, "content")
  defer directory_close(directory.fd)
  directory.write_new("a.md", b"foreign")
  assert_true(
    try {
      restore_trashed_post(input, item.id, item.record_digest) |> ignore
      false
    } catch {
      _ => true
    },
  )
  assert_eq(directory.read("a.md"), b"foreign")
  directory.remove("a.md")
  restore_trashed_post(input, item.id, item.record_digest) |> ignore
  assert_eq(read_post(input, "a.md").content, before.content)
  assert_eq(list_trashed_posts(input).length(), 0)
}
