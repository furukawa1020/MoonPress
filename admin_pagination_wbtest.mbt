///|
test "shared pagination handles boundaries and media navigation escapes filters" {
  assert_eq(admin_page_bounds(0, 1), (0, 0, 1))
  assert_eq(admin_page_bounds(20, 1), (0, 20, 1))
  assert_eq(admin_page_bounds(21, 2), (20, 21, 2))
  assert_eq(admin_page_bounds(40, 2), (20, 40, 2))
  assert_eq(
    admin_page_bounds(2147483647, 107374183),
    (2147483640, 2147483647, 107374183),
  )
  for (total, page) in [(0, 2), (21, 3), (20, 0), (-1, 1)] {
    let rejected = try {
      let _ = admin_page_bounds(total, page)
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  let html = admin_media_navigation("月 &", "attachments", 2, 3)
  assert_true(
    html.contains("q=%E6%9C%88%20%26&amp;kind=attachments&amp;page=1"),
  )
  assert_true(html.contains("&amp;page=3"))
  assert_false(admin_media_navigation("", "all", 1, 1).contains("href="))
}
