///|
// A canonical UTC instant, never local time, a locale-dependent date or leap second.
pub fn publication_timestamp(value : String) -> Int64 raise {
  if value.length() != 20 ||
    value[10:11] != "T" ||
    value[13:14] != ":" ||
    value[16:17] != ":" ||
    value[19:] != "Z" ||
    !valid_publication_date(value[:10].to_owned()) {
    raise InvalidInput(
      "publish_at must be a valid UTC YYYY-MM-DDTHH:MM:SSZ timestamp",
    )
  }
  let numbers : Array[Int] = []
  for
    part in [
      value[:4],
      value[5:7],
      value[8:10],
      value[11:13],
      value[14:16],
      value[17:19],
    ] {
    let mut n = 0
    for c in part {
      if !c.is_ascii_digit() {
        raise InvalidInput("publish_at requires decimal digits")
      }
      n = n * 10 + c.to_int() - 48
    }
    numbers.push(n)
  }
  let (year, month, day, hour, minute, second) = (
    numbers[0],
    numbers[1],
    numbers[2],
    numbers[3],
    numbers[4],
    numbers[5],
  )
  if hour > 23 || minute > 59 || second > 59 {
    raise InvalidInput("publish_at time is out of range")
  }
  let y = year - 1
  let mut days = y * 365 + y / 4 - y / 100 + y / 400 + day - 1 - 719162
  let leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
  let lengths = [
    31,
    if leap {
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
  for i = 0; i < month - 1; i = i + 1 {
    days += lengths[i]
  }
  days.to_int64() * 86400L + (hour * 3600 + minute * 60 + second).to_int64()
}

///|
fn publication_due(timestamp : String?, instant : Int64) -> Bool raise {
  match timestamp {
    None => true
    Some(timestamp) => {
      if instant < 0L {
        raise InvalidInput("Publication clock is unavailable")
      }
      publication_timestamp(timestamp) <= instant
    }
  }
}

///|
pub fn save_post_schedule(
  input : String,
  name : String,
  expected : String,
  timestamp : String,
) -> SavePostReport raise {
  let timestamp = timestamp.trim().to_owned()
  if !timestamp.is_empty() {
    publication_timestamp(timestamp) |> ignore
  }
  let snapshot = read_post(input, name)
  require_post_version(snapshot, expected)
  let document = parse_document(snapshot.content, name)
  if document.publish_at.unwrap_or("") == timestamp {
    return save_post(input, name, expected, snapshot.content)
  }
  let (metadata, body) = document_parts(snapshot.content, name)
  let fields = match metadata {
    Object(fields) => fields
    _ => raise InvalidInput("Frontmatter must be an object")
  }
  if timestamp.is_empty() {
    fields.remove("publish_at")
  } else {
    fields["publish_at"] = timestamp.to_json()
  }
  save_post(
    input,
    name,
    expected,
    "---\n" + metadata.stringify() + "\n---\n" + body,
  )
}
