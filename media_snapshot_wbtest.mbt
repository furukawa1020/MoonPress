///|
test "media snapshot filesystem probe" {
  guard @env.get_env_var("MOONPRESS_MEDIA_SNAPSHOT_PROBE") is Some(input) else {
    return
  }
  let item = read_media(input, "月 &a.PNG")
  assert_eq(item.bytes, 5)
  assert_eq(item.digest, digest_bytes(b"\x00\xffabc"))
  assert_eq(item.url, "%E6%9C%88%20%26a.PNG")
  assert_true(item.image)
  assert_eq(item.to_json(), list_media(input).items[0].to_json())
  for
    name in [
      "../outside.png", "missing.png", ".hidden.png", "style.css", "rss.xml", "bad.js",
    ] {
    assert_true(
      try {
        read_media(input, name) |> ignore
        false
      } catch {
        _ => true
      },
    )
  }
}

///|
test "media item reports byte length not decoded characters" {
  let item = media_item("a.pdf", b"\x00\xff\xc3\xa9")
  assert_eq(item.bytes, 4)
  assert_false(item.image)
  assert_eq(item.source, "public/a.pdf")
}

///|
test "media snapshot rejects unsafe filesystem kinds" {
  guard @env.get_env_var("MOONPRESS_MEDIA_UNSAFE_PROBE") is Some(input) else {
    return
  }
  for name in ["link.png", "pipe.png", "directory.png"] {
    assert_true(
      try {
        read_media(input, name) |> ignore
        false
      } catch {
        _ => true
      },
    )
  }
  assert_true(
    try {
      read_media(input + "/linked-site", "a.png") |> ignore
      false
    } catch {
      _ => true
    },
  )
}
