///|
fn rest_now_utc() -> String raise {
  let instant = authoring_time()
  if instant < 0L || instant > 253402300799L {
    raise InvalidInput("Publication clock unavailable")
  }
  let mut days = (instant / 86400L).to_int()
  let mut year = 1970
  while true {
    let length = if year % 4 == 0 && (year % 100 != 0 || year % 400 == 0) {
      366
    } else {
      365
    }
    if days < length {
      break
    }
    days -= length
    year += 1
  }
  let months = [
    31,
    if year % 4 == 0 && (year % 100 != 0 || year % 400 == 0) {
      29
    } else {
      28
    },
    31,
    30,
    31,
    30,
    31,
    31,
    30,
    31,
    30,
    31,
  ]
  let mut month = 0
  while days >= months[month] {
    days -= months[month]
    month += 1
  }
  let two = fn(n : Int) { (if n < 10 { "0" } else { "" }) + n.to_string() }
  let seconds = (instant % 86400L).to_int()
  year.to_string() +
  "-" +
  two(month + 1) +
  "-" +
  two(days + 1) +
  "T" +
  two(seconds / 3600) +
  ":" +
  two(seconds / 60 % 60) +
  ":" +
  two(seconds % 60)
}
