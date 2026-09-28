///|
test "repeated I/O fault descriptor probe" {
  if @env.get_env_var("MOONPRESS_IO_PROBE") is Some(path) {
    let mode = @env.get_env_var("MOONPRESS_IO_MODE").unwrap()
    let before = @fs.read_dir("/proc/self/fd").length()
    for i = 0; i < 16; i = i + 1 {
      let failed = try {
        if mode == "legacy-write" {
          @fs.write_bytes_to_file(path, b"0123456789abcdef")
        } else {
          write_bytes(path, b"0123456789abcdef")
        }
        false
      } catch {
        _ => true
      }
      assert_true(failed)
    }
    let growth = @fs.read_dir("/proc/self/fd").length() - before
    println(
      "I/O probe \{mode}: descriptor growth after 16 failures = \{growth}",
    )
    assert_eq(growth, if mode == "legacy-write" { 16 } else { 0 })
  }
}
