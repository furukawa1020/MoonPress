///|
test "ZIP CRC32 vectors and deterministic ordering" {
  assert_eq(zip_crc32(b"123456789"), 0xCBF43926U)
  assert_eq(zip_crc32(b""), 0U)
  let a : ZipEntry = { name: "a.txt", content: b"\x00\xff", }
  let b : ZipEntry = { name: "月.html", content: @utf8.encode("月"), }
  assert_eq(encode_site_zip([a, b]), encode_site_zip([b, a]))
  assert_eq(encode_site_zip([]).length(), 22)
  assert_eq(zip_entry_budget(22, 1, 67108764), 67108864)
  assert_true(
    try {
      zip_entry_budget(22, 1, 67108765) |> ignore
      false
    } catch {
      _ => true
    },
  )
}

///|
test "ZIP rejects unsafe internal and duplicate filenames" {
  for
    name in [
      "", "../a", "/a", "a/b", "a\\b", "a:b", ".moonpress.json", ".hidden", "a\u0000b",
    ] {
    assert_true(
      try {
        encode_site_zip([{ name, content: b"", }]) |> ignore
        false
      } catch {
        _ => true
      },
    )
  }
  let entry : ZipEntry = { name: "a.txt", content: b"", }
  assert_true(
    try {
      encode_site_zip([entry, entry]) |> ignore
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      encode_site_zip(Array::make(10001, entry)) |> ignore
      false
    } catch {
      _ => true
    },
  )
}

///|
test "ZIP interoperability fixture" {
  guard @env.get_env_var("MOONPRESS_ZIP_PROBE") is Some(path) else { return }
  write_bytes(
    path,
    encode_site_zip([
      { name: "月.html", content: @utf8.encode("<h1>月</h1>\n"), },
      { name: "binary.png", content: b"\x00\xff\x80abc", },
      { name: ".nojekyll", content: b"", },
    ]),
  )
}
