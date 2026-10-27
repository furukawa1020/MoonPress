///|
fn rest_input_date(fields : Map[String, Json]) -> Unit raise {
  if fields.get("date") is Some(value) {
    let date = match value {
      String(date) => date
      _ => raise InvalidInput("Expected native UTC date string")
    }
    if date.length() != 19 {
      raise InvalidInput("Expected second-precision native UTC date")
    }
    publication_timestamp(date + "Z") |> ignore
    if fields.get("date_gmt") is Some(other) && other != value {
      raise InvalidInput("Native date and date_gmt must agree")
    }
    fields["date_gmt"] = value
    fields.remove("date")
  }
}
