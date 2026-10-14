///|
fn flow_line(text : String, continued : Bool) -> (String, Bool) {
  if !continued {
    return (text, false)
  }
  if text.has_suffix("  ") {
    return (text.trim_end(chars=" ").to_owned(), true)
  }
  let trimmed = text.trim_end(chars="\\").to_owned()
  let slashes = text.length() - trimmed.length()
  if slashes % 2 == 1 {
    (text[:text.length() - 1].to_owned(), true)
  } else {
    (text, false)
  }
}

///|
fn flow_text(lines : Array[String]) -> Array[String] {
  let result : Array[String] = []
  for index = 0; index < lines.length(); index = index + 1 {
    result.push(flow_line(lines[index], index + 1 < lines.length()).0)
  }
  result
}

///|
fn render_flow(lines : Array[String]) -> String {
  let out = StringBuilder()
  for index = 0; index < lines.length(); index = index + 1 {
    let continued = index + 1 < lines.length()
    let (text, hard) = flow_line(lines[index], continued)
    out.write_string(render_inline(text))
    if continued {
      out.write_string(if hard { "<br>\n" } else { "\n" })
    }
  }
  out.to_string()
}
