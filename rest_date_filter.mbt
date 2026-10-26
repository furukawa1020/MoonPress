///|
// Native publication metadata uses UTC; normalize ISO8601 offsets for comparisons.
fn rest_date_bound(value : String) -> Int64 raise {
  if value.length() == 19 {
    return publication_timestamp(value + "Z")
  }
  if value.length() == 20 {
    return publication_timestamp(value)
  }
  if value.length() != 25 ||
    (value[19:20] != "+" && value[19:20] != "-") ||
    value[22:23] != ":" {
    raise InvalidInput("Invalid ISO8601 date bound")
  }
  let hours = value[20:22].to_owned()
  let minutes = value[23:25].to_owned()
  if !hours.all(c => c.is_ascii_digit()) ||
    !minutes.all(c => c.is_ascii_digit()) {
    raise InvalidInput("Invalid ISO8601 offset")
  }
  let h = (hours[0].to_int() - 48) * 10 + hours[1].to_int() - 48
  let m = (minutes[0].to_int() - 48) * 10 + minutes[1].to_int() - 48
  if h > 23 || m > 59 {
    raise InvalidInput("Invalid ISO8601 offset")
  }
  let seconds = (h * 3600 + m * 60).to_int64()
  publication_timestamp(value[:19].to_owned() + "Z") +
  (if value[19:20] == "+" { 0L - seconds } else { seconds })
}

///|
fn rest_post_timestamp(doc : Document) -> Int64 raise {
  publication_timestamp(
    doc.publish_at.unwrap_or(doc.date.unwrap_or("1970-01-01") + "T00:00:00Z"),
  )
}
