///|
test "revision line comparison preserves both sources without executing markup" {
  let result = revision_line_diff("same\n<script>\nend", "same\nnew 月\nend")
  assert_eq(result.map(line => line.action), ["keep", "remove", "add", "keep"])
  assert_eq(
    result
    .filter(line => line.action != "add")
    .map(line => line.text)
    .join("\n"),
    "same\n<script>\nend",
  )
  assert_eq(
    result
    .filter(line => line.action != "remove")
    .map(line => line.text)
    .join("\n"),
    "same\nnew 月\nend",
  )
  assert_true(
    try {
      revision_line_diff(String::make(262145, 'x'), "") |> ignore
      false
    } catch {
      _ => true
    },
  )
}
