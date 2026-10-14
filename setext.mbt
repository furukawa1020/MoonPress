///|
fn setext_level(line : String) -> Int {
  let marker = line.trim_end(chars=" \t").to_owned()
  if marker.length() < 3 {
    return 0
  }
  if marker.all(c => c == '=') {
    1
  } else if marker.all(c => c == '-') {
    2
  } else {
    0
  }
}
