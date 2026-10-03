///|
test "post search combines state with title filename and tag matching" {
  let draft : PostSummary = {
    source: "content/draft.md",
    output: "draft.html",
    title: "Moon Draft",
    draft: true,
    listed: true,
    date: None,
    tags: ["月", "Compiler"],
  }
  let ready : PostSummary = {
    ..draft,
    source: "content/ready.md",
    title: "Ready",
    draft: false,
    listed: false,
    tags: [],
  }
  let posts = [draft, ready]
  assert_eq(filter_posts(posts, " moon ", "all").length(), 1)
  assert_eq(filter_posts(posts, "COMPILER", "draft").length(), 1)
  assert_eq(filter_posts(posts, "月", "ready").length(), 0)
  assert_eq(filter_posts(posts, "READY.MD", "all")[0].title, "Ready")
  assert_eq(filter_posts(posts, "", "unlisted")[0].title, "Ready")
  assert_eq(filter_posts(posts, "", "all")[0].title, "Moon Draft")
  assert_eq(posts.length(), 2)
  try filter_posts(posts, "", "published") catch {
    _ => ()
  } noraise {
    _ => fail("invalid state accepted")
  }
}

///|
test "post page parsing and navigation are bounded and escape queries" {
  assert_eq(admin_post_page("2"), 2)
  for value in ["", "0", "-1", "+1", "1.5", "999999999", " 1", "a"] {
    try admin_post_page(value) catch {
      _ => ()
    } noraise {
      _ => fail("invalid page accepted")
    }
  }
  let html = admin_post_navigation("月 &", "draft", 2, 3)
  assert_true(html.contains("q=%E6%9C%88%20%26&amp;state=draft&amp;page=1"))
  assert_true(html.contains("&amp;page=3"))
  assert_false(admin_post_navigation("", "all", 1, 1).contains("href="))
  assert_true(
    admin_post_search_form("\"><script>", "draft").contains(
      "&quot;&gt;&lt;script&gt;",
    ),
  )
}
