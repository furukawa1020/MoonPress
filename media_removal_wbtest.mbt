///|
test "media removal inspection filesystem probe" {
  guard @env.get_env_var("MOONPRESS_REMOVAL_PLAN_PROBE") is Some(root) else {
    return
  }
  let input = root + "/site"
  init_site(input) |> ignore
  @fs.create_dir(input + "/public")
  write_bytes(input + "/public/月.png", b"image")
  let first = inspect_media_removal(input, "月.png")
  assert_false(first.blocked)
  assert_true(first.references.is_empty())
  assert_eq(first.review_id, inspect_media_removal(input, "月.png").review_id)
  assert_eq(first.item.digest, digest_bytes(b"image"))
  assert_true(first.scope.contains("CSS"))
  assert_eq(path_kind(input + "/.moonpress-build"), 0)
  write_text(
    input + "/content/private.md",
    "---\n{\"draft\":true}\n---\n# Private\n\n![月](%E6%9C%88.png)\n",
  )
  let draft = inspect_media_removal(input, "月.png")
  assert_true(draft.blocked)
  assert_true(draft.references.any(edge => edge.source == "content/private.md"))
  assert_true(first.review_id != draft.review_id)
  write_text(input + "/content/private.md", "# Private without image\n")
  let layout = read_text(input + "/layout.html")
  write_text(input + "/layout.html", layout + "<img src=\"%E6%9C%88.png\">")
  let template = inspect_media_removal(input, "月.png")
  assert_true(template.blocked)
  assert_true(template.references.any(edge => edge.source == "layout.html"))
  write_text(input + "/layout.html", layout)
  let unreferenced = inspect_media_removal(input, "月.png")
  write_bytes(input + "/public/月.png", b"changed")
  assert_true(
    unreferenced.review_id != inspect_media_removal(input, "月.png").review_id,
  )
  write_text(input + "/content/private.md", "---\n{broken\n---\n# Broken\n")
  assert_true(
    try {
      inspect_media_removal(input, "月.png") |> ignore
      false
    } catch {
      _ => true
    },
  )
  assert_eq(read_bytes(input + "/public/月.png"), b"changed")
}

///|
test "reviewed media removal filesystem probe" {
  guard @env.get_env_var("MOONPRESS_REMOVAL_PROBE") is Some(root) else {
    return
  }
  let input = root + "/site"
  let output = root + "/out"
  init_site(input) |> ignore
  @fs.create_dir(input + "/public")
  write_bytes(input + "/public/a.png", b"image")
  compile_site(input, output) |> ignore
  let manifest = read_bytes(output + "/.moonpress.json")
  let first = inspect_media_removal(input, "a.png")
  assert_true(
    try {
      remove_media(input, "a.png", first.review_id, acknowledge_unscanned=false)
      |> ignore
      false
    } catch {
      _ => true
    },
  )
  write_text(
    input + "/content/private.md",
    "---\n{\"draft\":true}\n---\n# Private\n\n![image](a.png)\n",
  )
  let blocked = inspect_media_removal(input, "a.png")
  for id in ["bad", first.review_id, blocked.review_id] {
    assert_true(
      try {
        remove_media(input, "a.png", id, acknowledge_unscanned=true) |> ignore
        false
      } catch {
        _ => true
      },
    )
  }
  assert_eq(read_bytes(input + "/public/a.png"), b"image")
  write_text(input + "/content/private.md", "# No image\n")
  let unreferenced = inspect_media_removal(input, "a.png")
  write_bytes(input + "/public/a.png", b"new")
  assert_true(
    try {
      remove_media(
        input,
        "a.png",
        unreferenced.review_id,
        acknowledge_unscanned=true,
      )
      |> ignore
      false
    } catch {
      _ => true
    },
  )
  let fresh = inspect_media_removal(input, "a.png")
  let removed = remove_media(
    input,
    "a.png",
    fresh.review_id,
    acknowledge_unscanned=true,
  )
  assert_eq(removed.item.digest, digest_bytes(b"new"))
  assert_eq(path_kind(input + "/public/a.png"), 0)
  assert_eq(read_bytes(output + "/a.png"), b"image")
  assert_eq(read_bytes(output + "/.moonpress.json"), manifest)
  assert_true(
    try {
      remove_media(input, "a.png", fresh.review_id, acknowledge_unscanned=true)
      |> ignore
      false
    } catch {
      _ => true
    },
  )
  compile_site(input, output) |> ignore
  assert_eq(path_kind(output + "/a.png"), 0)
  compile_site(input, root + "/clean") |> ignore
  assert_eq(
    read_bytes(output + "/.moonpress.json"),
    read_bytes(root + "/clean/.moonpress.json"),
  )
}

///|
test "media removal failure descriptor lifecycle probe" {
  guard @env.get_env_var("MOONPRESS_REMOVAL_FAILURE_PROBE") is Some(root) else {
    return
  }
  let input = root + "/site"
  let plan = inspect_media_removal(input, "a.png")
  let before = @fs.read_dir("/proc/self/fd").length()
  for i = 0; i < 16; i = i + 1 {
    assert_true(
      try {
        remove_media(input, "a.png", plan.review_id, acknowledge_unscanned=true)
        |> ignore
        false
      } catch {
        _ => true
      },
    )
    assert_eq(
      digest_bytes(read_bytes(input + "/public/a.png")),
      plan.item.digest,
    )
  }
  assert_eq(@fs.read_dir("/proc/self/fd").length(), before)
}
