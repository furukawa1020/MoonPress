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
