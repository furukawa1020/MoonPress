///|
test "redirect graph resolves chains deterministically without mutating input" {
  let redirects : Array[@moonpress.Redirect] = [
    { name: "z.html", target: "a.html", },
    { name: "a.html", target: "月😀.html", },
  ]
  let resolved = @moonpress.resolve_redirects(redirects, [
    "月😀.html", "style.css",
  ])
  assert_eq(resolved[0].name, "a.html")
  assert_eq(resolved[1].target, "月😀.html")
  assert_eq(redirects[0].target, "a.html")
  assert_eq(@moonpress.resolve_redirects([], []).length(), 0)
  let html = @moonpress.render_redirect(
    "月😀.html",
    base_url=Some("https://example.org/project"),
  )
  assert_true(html.contains("content=\"0; url=%E6%9C%88%F0%9F%98%80.html\""))
  assert_true(
    html.contains("rel=\"canonical\" href=\"https://example.org/project/"),
  )
  assert_true(html.contains(">月😀.html</a>"))
  assert_true(!html.contains("<script"))
  assert_true(!@moonpress.render_redirect("a.html").contains("canonical"))
}

///|
test "redirect graph rejects collisions cycles dangling and unsafe mappings" {
  let cases : Array[Array[@moonpress.Redirect]] = [
    [{ name: "a.html", target: "a.html", }],
    [
      { name: "a.html", target: "b.html", },
      { name: "b.html", target: "a.html", },
    ],
    [{ name: "a.html", target: "missing.html", }],
    [{ name: "index.html", target: "index.html", }],
    [
      { name: "a.html", target: "index.html", },
      { name: "a.html", target: "index.html", },
    ],
    [{ name: "../old.html", target: "index.html", }],
    [{ name: "a.html", target: "https://example.org/new.html", }],
    [{ name: "a.html", target: "style.css", }],
  ]
  for redirects in cases {
    assert_true(
      try {
        let _ = @moonpress.resolve_redirects(redirects, [
          "index.html", "style.css",
        ])
        false
      } catch {
        _ => true
      },
    )
  }
  assert_true(
    try {
      let _ = @moonpress.render_redirect(
        "x.html",
        base_url=Some("javascript:alert"),
      )
      false
    } catch {
      _ => true
    },
  )
  let html = @moonpress.render_redirect("a\"&b.html")
  assert_true(html.contains("a%22%26b.html"))
  assert_true(html.contains("a&quot;&amp;b.html</a>"))
}

///|
test "long shared redirect chains use iterative terminal resolution" {
  let mappings : Array[@moonpress.Redirect] = []
  for index = 0; index < 2000; index = index + 1 {
    mappings.push({
      name: "old-\{index}.html",
      target: if index == 1999 {
        "index.html"
      } else {
        "old-\{index+1}.html"
      },
    })
  }
  let result = @moonpress.resolve_redirects(mappings, ["index.html"])
  assert_eq(result.length(), 2000)
  assert_true(result.all(r => r.target == "index.html"))
  assert_eq(mappings[0].target, "old-1.html")
}
