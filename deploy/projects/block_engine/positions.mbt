///|
pub fn insertion_index(length : Int, selected : Int) -> Int {
  if selected < 0 || selected >= length {
    length
  } else {
    selected + 1
  }
}
