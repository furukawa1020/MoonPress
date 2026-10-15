///|
test "guarded media reader closes descriptors on stream failure" {
  guard @env.get_env_var("MOONPRESS_MEDIA_GUARD_PROBE") is Some(input) else {
    return
  }
  let before = @fs.read_dir("/proc/self/fd").length()
  for i = 0; i < 32; i = i + 1 {
    assert_true(
      try {
        read_media(input, "a.png") |> ignore
        false
      } catch {
        _ => true
      },
    )
  }
  let after = @fs.read_dir("/proc/self/fd").length()
  assert_eq(after, before)
}
