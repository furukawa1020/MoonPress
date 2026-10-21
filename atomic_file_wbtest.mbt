///|
test "anonymous publication filesystem probe" {
  guard @env.get_env_var("MOONPRESS_ATOMIC_PROBE") is Some(path) else { return }
  let before = @fs.read_dir("/proc/self/fd").length()
  if @env.get_env_var("MOONPRESS_ATOMIC_FAIL") is Some(_) {
    for _ in 0..<32 {
      assert_true(
        try {
          write_atomic_new(path, b"binary\x00payload")
          false
        } catch {
          _ => true
        },
      )
      assert_eq(path_kind(path), 0)
    }
  } else {
    for bytes in [b"", b"binary\x00\xffpayload"] {
      write_atomic_new(path, bytes)
      assert_eq(read_bytes(path), bytes)
      assert_true(
        try {
          write_atomic_new(path, b"overwrite")
          false
        } catch {
          _ => true
        },
      )
      assert_eq(read_bytes(path), bytes)
      @fs.remove_file(path)
    }
  }
  assert_eq(@fs.read_dir("/proc/self/fd").length(), before)
}
