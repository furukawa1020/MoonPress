///|
pub fn insertion_index(length : Int, selected : Int) -> Int {
  if selected < 0 || selected >= length {
    length
  } else {
    selected + 1
  }
}

///|
pub fn movement_index(length : Int, selected : Int, step : Int) -> Int {
  if selected < 0 || selected >= length || (step != -1 && step != 1) {
    return -1
  }
  let destination = selected + step
  if destination >= 0 && destination < length {
    destination
  } else {
    -1
  }
}
