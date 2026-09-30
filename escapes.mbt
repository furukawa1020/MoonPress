///|
// ASCII punctuation only; whitespace, letters and Unicode retain their slash.
fn escape_width(text : String, offset : Int) -> Int {
  if offset + 1 < text.length() {
    let c = text[offset + 1].to_int()
    if (c >= 33 && c <= 47) ||
      (c >= 58 && c <= 64) ||
      (c >= 91 && c <= 96) ||
      (c >= 123 && c <= 126) {
      return 2
    }
  }
  1
}

///|
// Labels are plain text. Escaped brackets do not nest or close a label.
fn label_end(text : String) -> Int? {
  let mut offset = 0
  while offset < text.length() {
    if text[offset:offset + 1] == "\\" {
      offset += escape_width(text, offset)
    } else if text[offset:offset + 1] == "[" {
      return None
    } else if text[offset:].has_prefix("](") {
      return Some(offset)
    } else {
      offset += 1
    }
  }
  None
}

///|
fn unescape_label(text : String) -> String {
  let out = StringBuilder()
  let mut rest = text
  while rest.find("\\") is Some(offset) {
    out.write_string(rest[:offset].to_owned())
    let width = escape_width(rest, offset)
    out.write_string(
      rest[offset + (if width == 2 { 1 } else { 0 }):offset + width].to_owned(),
    )
    rest = rest[offset + width:].to_owned()
  }
  out.write_string(rest)
  out.to_string()
}
