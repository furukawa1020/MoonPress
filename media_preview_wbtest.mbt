///|
test "raster preview signatures require matching supported extensions" {
  for
    (name, bytes, mime) in [
      ("月.PNG", b"\x89PNG\r\n\x1a\n", "image/png"),
      ("a.JPEG", b"\xff\xd8\xff", "image/jpeg"),
      ("a.gif", b"GIF89a", "image/gif"),
      ("a.webp", b"RIFF\x00\x00\x00\x00WEBP", "image/webp"),
    ] {
    assert_eq(raster_preview_mime(name), Some(mime))
    assert_true(media_preview_signature(mime, bytes))
    assert_false(media_preview_signature(mime, b"<html>"))
    assert_false(media_preview_signature(mime, b""))
  }
  for name in ["a.svg", "a.html", "a.avif", "a.ico", "a.pdf"] {
    assert_eq(raster_preview_mime(name), None)
  }
  assert_false(media_preview_signature("image/png", b"GIF89a"))
}

///|
test "media preview guarded filesystem probe" {
  guard @env.get_env_var("MOONPRESS_IMAGE_PROBE") is Some(input) else { return }
  let preview = read_media_preview(input, "a.png")
  assert_eq(preview.mime, "image/png")
  assert_eq(preview.item.digest, digest_bytes(preview.content))
  assert_eq(
    read_media_preview(input, "a.png", expected=Some(preview.item.digest)).content,
    preview.content,
  )
  assert_eq(read_media_preview(input, "limit.png").item.bytes, 8388608)
  for expected in ["bad", digest_bytes(b"different")] {
    assert_true(
      try {
        read_media_preview(input, "a.png", expected=Some(expected)) |> ignore
        false
      } catch {
        _ => true
      },
    )
  }
  let before = @fs.read_dir("/proc/self/fd").length()
  for i = 0; i < 16; i = i + 1 {
    for
      name in [
        "huge.png", "wrong.png", "link.png", "pipe.png", "dir.png", "missing.png",
        "../a.png", "a.svg",
      ] {
      assert_true(
        try {
          read_media_preview(input, name) |> ignore
          false
        } catch {
          _ => true
        },
      )
    }
  }
  assert_eq(@fs.read_dir("/proc/self/fd").length(), before)
  assert_true(
    try {
      read_media_preview(input + "/alias", "a.png") |> ignore
      false
    } catch {
      _ => true
    },
  )
}

///|
test "media preview refuses substituted paths and closes failed streams" {
  guard @env.get_env_var("MOONPRESS_IMAGE_FAILURE_PROBE") is Some(input) else {
    return
  }
  let before = @fs.read_dir("/proc/self/fd").length()
  for i = 0; i < 32; i = i + 1 {
    assert_true(
      try {
        read_media_preview(input, "a.png") |> ignore
        false
      } catch {
        _ => true
      },
    )
  }
  assert_eq(@fs.read_dir("/proc/self/fd").length(), before)
}

///|
test "media preview retains original directory after replacement" {
  guard @env.get_env_var("MOONPRESS_IMAGE_DIRECTORY_PROBE") is Some(input) else {
    return
  }
  assert_eq(
    read_media_preview(input, "a.png").content,
    b"\x89PNG\r\n\x1a\noriginal",
  )
}
