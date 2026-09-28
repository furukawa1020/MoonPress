///|
test "repeated I/O fault descriptor probe" {
  if @env.get_env_var("MOONPRESS_IO_PROBE") is Some(path) {
    let mode = @env.get_env_var("MOONPRESS_IO_MODE").unwrap()
    let before = @fs.read_dir("/proc/self/fd").length()
    for i = 0; i < 16; i = i + 1 {
      let message = try {
        if mode == "legacy-write" {
          @fs.write_bytes_to_file(path, b"0123456789abcdef")
        } else if mode == "legacy-read" {
          @fs.read_file_to_bytes(path) |> ignore
        } else if mode == "read" {
          read_bytes(path) |> ignore
        } else {
          write_bytes(path, b"0123456789abcdef")
        }
        ""
      } catch {
        error => "\{error}"
      }
      assert_false(message.is_empty())
      if @env.get_env_var("MOONPRESS_IO_EXPECT_ERROR") is Some(expected) {
        assert_true(message.contains(expected))
      }
    }
    let growth = @fs.read_dir("/proc/self/fd").length() - before
    println(
      "I/O probe \{mode}: descriptor growth after 16 failures = \{growth}",
    )
    assert_eq(growth, if mode.has_prefix("legacy-") { 16 } else { 0 })
  }
}

///|
test "strict text decoder rejects malformed UTF8 and preserves BOM" {
  assert_eq(decode_text(b"\xef\xbb\xbfhello", "text"), "\uFEFFhello")
  assert_eq(decode_text(@utf8.encode("月🌙"), "text"), "月🌙")
  for
    bytes in [b"\xe3\x81", b"\xc0\xaf", b"\xe3x\x82", b"\xff", b"\xed\xa0\x80"] {
    let error = try {
      decode_text(bytes, "content/bad.md") |> ignore
      ""
    } catch {
      error => "\{error}"
    }
    assert_true(error.contains("Invalid UTF-8 text: content/bad.md"))
  }
}
