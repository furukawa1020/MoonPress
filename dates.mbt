///|
// A calendar date, not a clock or scheduling policy. Fixed width makes ordering
// independent of timezone, locale, filesystem timestamps and build time.
fn valid_publication_date(value : String) -> Bool {
  if value.length() != 10 || value[4:5] != "-" || value[7:8] != "-" {
    return false
  }
  let parts = [
    value[:4].to_owned(),
    value[5:7].to_owned(),
    value[8:].to_owned(),
  ]
  let numbers : Array[Int] = []
  for part in parts {
    let mut number = 0
    for c in part {
      if !c.is_ascii_digit() {
        return false
      }
      number = number * 10 + c.to_int() - 48
    }
    numbers.push(number)
  }
  let year = numbers[0]
  let month = numbers[1]
  let day = numbers[2]
  if year == 0 || month < 1 || month > 12 || day < 1 {
    return false
  }
  let leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
  let maximum = match month {
    2 => if leap { 29 } else { 28 }
    4 | 6 | 9 | 11 => 30
    _ => 31
  }
  day <= maximum
}

///|
fn chronological_pages(pages : Array[Page]) -> Array[Page] {
  let ordered = pages.copy()
  ordered.sort_by((a, b) => {
    let date_order = match (a.document.date, b.document.date) {
      (Some(a), Some(b)) => b.compare(a)
      (Some(_), None) => -1
      (None, Some(_)) => 1
      (None, None) => 0
    }
    if date_order == 0 {
      a.output.compare(b.output)
    } else {
      date_order
    }
  })
  ordered
}
