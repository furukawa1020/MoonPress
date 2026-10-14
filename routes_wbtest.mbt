///|
test "route inventory sorting preserves sources targets and input order" {
  let routes : Array[RouteInfo] = [
    {
      name: "z.html",
      kind: "redirect",
      source: Some("site.json/redirects/z.html"),
      target: Some("a.html"),
    },
    {
      name: "a.html",
      kind: "page",
      source: Some("content/a.md"),
      target: None,
    },
  ]
  let sorted = sorted_routes(routes)
  assert_eq(sorted[0].name, "a.html")
  assert_eq(sorted[1].target, Some("a.html"))
  assert_eq(sorted[0].source, Some("content/a.md"))
  assert_eq(routes[0].name, "z.html")
  assert_eq(sorted_routes([]).length(), 0)
}
