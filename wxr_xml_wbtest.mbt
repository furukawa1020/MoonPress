///|
test "WXR XML entities CDATA UTF8 and namespace boundaries" {
  let root = parse_wxr_xml(
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?><!-- before --><root x='&amp;'><child><![CDATA[月 <&>]]>&#13;&#x1F600;</child></root><!-- after -->",
  )
  assert_eq(root.attributes.get("x"), Some("&"))
  assert_eq(root.field("child"), "月 <&>\r😀")
  for
    invalid in [
      "<!DOCTYPE x [<!ENTITY e SYSTEM 'file:///etc/passwd'>]><x>&e;</x>", "<x>&unknown;</x>",
      "<x>&#0;</x>", "<x>&#xD800;</x>", "<x>&#99999999;</x>", "<x a='1' a='2'/>",
      "<x><y></x>", "<x/>extra", "<x/><?pi?>", "<x>bad ]]></x>", "<x><!-- bad -- comment --></x>",
    ] {
    let mut rejected = false
    try parse_wxr_xml(invalid) |> ignore catch {
      _ => rejected = true
    }
    assert_true(rejected)
  }
  let mut deep = ""
  for i = 0; i < 40; i = i + 1 {
    deep += "<x>"
  }
  for i = 0; i < 40; i = i + 1 {
    deep += "</x>"
  }
  let mut rejected = false
  try parse_wxr_xml(deep) |> ignore catch {
    _ => rejected = true
  }
  assert_true(rejected)
}

///|
test "WXR simple HTML preserves browser whitespace semantics" {
  assert_eq(wxr_body("<p>    Text\n\n  more</p>"), "Text more\n\n")
  assert_eq(wxr_body("<h2> Heading\n next </h2>"), "## Heading next\n\n")
  assert_eq(wxr_body("    literal text"), "literal text")
}
