///|
test "admin form decoder preserves Unicode and rejects ambiguity" {
  let fields = admin_form("title=%E6%9C%88+%26+%2B&content=a%0D%0Ab%3D%3C")
  assert_eq(fields.get("title"), Some("月 & +"))
  assert_eq(fields.get("content"), Some("a\r\nb=<"))
  for body in ["a=1&a=2", "%61=1&a=2", "x=%", "x=%FF", "x=%GG", "missing"] {
    try admin_form(body) catch {
      _ => ()
    } noraise {
      _ => fail("bad form accepted: " + body)
    }
  }
}

///|
test "admin HTTP framing and origin are strictly bounded" {
  let host = "127.0.0.1:8080"
  let raw = "POST /save HTTP/1.1\r\nHost: " +
    host +
    "\r\nOrigin: http://" +
    host +
    "\r\nContent-Type: application/x-www-form-urlencoded\r\nContent-Length: 12\r\n"
  assert_eq(admin_headers(raw + "\r\n", host).length, 12)
  for
    suffix in [
      "Host: evil\r\n", "Transfer-Encoding: chunked\r\n", "Content-Length: 0\r\n",
      "Content-Encoding: gzip\r\n", "Expect: 100-continue\r\n", "Sec-Fetch-Site: cross-site\r\n",
      " folded: value\r\n",
    ] {
    try admin_headers(raw + suffix + "\r\n", host) catch {
      _ => ()
    } noraise {
      _ => fail("ambiguous header accepted")
    }
  }
  for
    raw in [
      "GET / HTTP/1.1\r\nHost: localhost:8080\r\n\r\n", "GET / HTTP/1.1\r\nHost: 127.0.0.1:8080\r\nContent-Length: 1\r\n\r\n",
      "POST /save HTTP/1.1\r\nHost: 127.0.0.1:8080\r\nContent-Length: 262145\r\n\r\n",
      "POST /save HTTP/1.1\r\nHost: 127.0.0.1:8080\r\nContent-Length: 0\r\nContent-Type: application/x-www-form-urlencoded\r\n\r\n",
    ] {
    try admin_headers(raw, host) catch {
      _ => ()
    } noraise {
      _ => fail("unsafe request accepted")
    }
  }
}

///|
test "admin shell escapes titles and disables executable content" {
  let html = admin_page("<script>", "<p>Trusted body</p>")
  assert_true(html.contains("&lt;script&gt;"))
  assert_false(html.contains("<script>"))
  assert_eq(
    admin_hidden("name", "\"<>&"),
    "<input type=\"hidden\" name=\"name\" value=\"&quot;&lt;&gt;&amp;\">",
  )
  let response = decode_text(admin_response(200, "月"), "test")
  assert_true(response.contains("Content-Length: 3\r\n"))
  assert_true(response.contains("default-src 'none'"))
  assert_true(response.contains("Cache-Control: no-store"))
}

///|
test "body preview renders Markdown but disables destinations and raw HTML" {
  let html = admin_body_preview(
    "# Moon\n\n**bold** [next](guide.html) ![alt](image.png)\n\n</article><form action='/save'><script>bad</script>\n\n[bad](javascript:alert)\n",
  )
  assert_true(html.contains("<strong>bold</strong>"))
  assert_true(html.contains("data-preview-href=\"guide.html\""))
  assert_true(html.contains("data-preview-src=\"image.png\""))
  assert_false(html.contains("<a href="))
  assert_false(html.contains("<img src="))
  assert_false(html.contains("<form"))
  assert_false(html.contains("<script>"))
  assert_true(html.contains("&lt;script&gt;bad&lt;/script&gt;"))
  assert_false(html.contains("href=\"javascript:"))
}

///|
test "inventory diagnostics escape input and only link editable sources" {
  let html = admin_post_problems([
    {
      source: "content/bad &.md",
      message: "<script>bad</script>",
      editable: true,
    },
    { source: "content/link.md", message: "symlink", editable: false, },
  ])
  assert_true(html.contains("&lt;script&gt;"))
  assert_false(html.contains("<script>"))
  assert_true(html.contains("/edit?name=bad%20%26.md"))
  assert_false(html.contains("/edit?name=link.md"))
  assert_eq(admin_post_problems([]), "")
}

///|
test "media snippets encode filenames and classify extensions only" {
  let url = url_component("月 (a)&.PNG")
  assert_eq(url, "%E6%9C%88%20%28a%29%26.PNG")
  let item : MediaItem = {
    source: "public/x",
    url,
    bytes: 3,
    digest: "digest",
    image: true,
  }
  assert_eq(media_snippet(item), "![Describe image](" + url + ")")
  assert_eq(media_snippet({ ..item, image: false, }), "[Download](" + url + ")")
  assert_true(image_asset_name("x.PNG"))
  assert_false(image_asset_name("x.pdf"))
}
