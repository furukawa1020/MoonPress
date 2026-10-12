///|
test "media references reuse rendering syntax and route normalization" {
  let body = "![one](./%E7%94%BB%E5%83%8F%20%28a%29.PNG?x=1#top)\n[again](/project/%E7%94%BB%E5%83%8F%20%28a%29.PNG)\n`[code](skip.pdf)`\n\\[escaped](skip.pdf)\n```\n![fence](skip.pdf)\n```\n[external](https://example.org/skip.pdf)\n[letter](%61.pdf)"
  let routes = media_routes(body, "/project/", "article")
  assert_eq(routes.length(), 2)
  assert_true(routes.contains("%E7%94%BB%E5%83%8F%20%28a%29.PNG"))
  assert_true(routes.contains("a.pdf"))
}

///|
test "media references expose invalid destinations" {
  for
    body in [
      "[bad](%ZZ.pdf)", "![bad](mailto:a)", "[bad](/outside/a.pdf)", "[bad](javascript:run)",
    ] {
    let rejected = try {
      let _ = media_routes(body, "/project/", "article")
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}
