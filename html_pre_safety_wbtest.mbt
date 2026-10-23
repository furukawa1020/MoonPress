///|
test "pre refuses significant siblings around code instead of discarding them" {
  for
    text in [
      "<pre>  <code>x</code>  </pre>", "<pre>\n<code>x</code></pre>", "<pre><code>x</code>\n</pre>",
    ] {
    let refused = try {
      wxr_body(text) |> ignore
      false
    } catch {
      _ => true
    }
    assert_true(refused)
  }
}
