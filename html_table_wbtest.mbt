///|
test "HTML tables preserve rectangular inline cells and escaped pipes" {
  let source = "<table><tr><th scope='col'>Name</th><th>Value</th></tr><tr><td>A | B</td><td><strong>two</strong></td></tr></table>"
  assert_eq(
    render_markdown(wxr_body(source)),
    "<table>\n<thead>\n<tr><th scope=\"col\">Name</th><th scope=\"col\">Value</th></tr>\n</thead>\n<tbody>\n<tr><td>A | B</td><td><strong>two</strong></td></tr>\n</tbody>\n</table>\n",
  )
  for
    source in [
      "<table></table>", "<table><tr><td>Missing header</td></tr></table>", "<table><tr><th>A</th><th>B</th></tr><tr><td>Ragged</td></tr></table>",
      "<table><tr><th>X</th></tr><tr><td colspan='2'>Y</td></tr></table>",
    ] {
    let mut refused = false
    try wxr_body(source) |> ignore catch {
      _ => refused = true
    }
    assert_true(refused)
  }
}
