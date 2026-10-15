///|
test "media replacement filesystem probe" {
  guard @env.get_env_var("MOONPRESS_MEDIA_REPLACE_PROBE") is Some(input) else {
    return
  }
  let name = "a.png"
  let before = read_media(input, name)
  let no_op = replace_media(input, name, before.digest, b"\x00\xffold")
  assert_false(no_op.changed)
  assert_eq(no_op.item.digest, before.digest)
  let changed = replace_media(input, name, before.digest, b"\xff\x00new")
  assert_true(changed.changed)
  assert_eq(changed.previous_digest, before.digest)
  assert_eq(read_bytes(input + "/public/a.png"), b"\xff\x00new")
  assert_eq(changed.item.to_json(), read_media(input, name).to_json())
  assert_eq(changed.item.url, before.url)
  for expected in [before.digest, "bad", changed.item.digest.to_upper()] {
    assert_true(
      try {
        replace_media(input, name, expected, b"overwrite") |> ignore
        false
      } catch {
        _ => true
      },
    )
  }
  assert_eq(read_bytes(input + "/public/a.png"), b"\xff\x00new")
  let empty = replace_media_from_file(
    input,
    name,
    changed.item.digest,
    input + "/empty",
  )
  assert_true(empty.changed)
  assert_eq(empty.item.bytes, 0)
  assert_eq(read_bytes(input + "/empty"), b"")
  assert_eq(path_kind(input + "/public/.moonpress-media-edit"), 0)
}

///|
test "media version rejects invalid digests and stale values" {
  let item = media_item("a.png", b"x")
  require_media_version(item, item.digest)
  for expected in ["", "wrong", item.digest.to_upper(), digest_bytes(b"y")] {
    assert_true(
      try {
        require_media_version(item, expected)
        false
      } catch {
        _ => true
      },
    )
  }
}
