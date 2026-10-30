///|
test "media IDs are scoped stable and positive" {
  assert_true(wp_media_id("a.png") > 0)
  assert_eq(wp_media_id("a.png"), wp_media_id("a.png"))
  assert_true(wp_media_id("a.png") != wp_media_id("A.png"))
  assert_true(wp_media_id("a.png") != rest_term_id("category", "a.png"))
}

///|
test "media collision refuses the complete snapshot" {
  let a : WpMedia = { id: 1, name: "a.png", bytes: 1, mime: "image/png", }
  let b : WpMedia = { ..a, name: "b.png", }
  let refused = try {
    wp_media_validate_ids([a, b])
    false
  } catch {
    _ => true
  }
  assert_true(refused)
}
