///|
test "anonymous authoring filesystem probe" {
  guard @env.get_env_var("MOONPRESS_AUTHORING_ATOMIC_PROBE") is Some(path) else {
    return
  }
  let before = @fs.read_dir("/proc/self/fd").length()
  {
    let directory = open_authoring_directory(path)
    defer directory_close(directory.fd)
    directory.lock()
    if @env.get_env_var("MOONPRESS_ATOMIC_VISIBLE") is Some(expected) {
      assert_true(
        try {
          directory.write_new("atomic", b"binary\x00payload")
          false
        } catch {
          _ => true
        },
      )
      assert_eq(
        directory.read("atomic"),
        if expected == "race" {
          b"competing writer\n"
        } else {
          b"binary\x00payload"
        },
      )
      @fs.remove_file(path + "/atomic")
    } else if @env.get_env_var("MOONPRESS_ATOMIC_FAIL") is Some(_) {
      for _ in 0..<32 {
        assert_true(
          try {
            directory.write_new("atomic", b"binary\x00payload")
            false
          } catch {
            _ => true
          },
        )
        assert_eq(directory.kind("atomic"), 0)
      }
    } else {
      for bytes in [b"", b"binary\x00\xffpayload"] {
        directory.write_new("atomic", bytes)
        assert_eq(directory.read("atomic"), bytes)
        assert_true(
          try {
            directory.write_new("atomic", b"overwrite")
            false
          } catch {
            _ => true
          },
        )
        assert_eq(directory.read("atomic"), bytes)
        directory.remove("atomic")
      }
    }
  }
  assert_eq(@fs.read_dir("/proc/self/fd").length(), before)
}
