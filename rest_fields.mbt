///|
fn rest_fields(value : String?) -> Array[String] raise {
  let fields : Array[String] = []
  if value is Some(value) && !value.trim().is_empty() {
    if value.length() > 2048 {
      raise InvalidInput("Field selection exceeds limit")
    }
    for field in value.split(",") {
      let field = field.trim().to_owned()
      let parts = field.split(".").to_array()
      if parts.length() > 8 ||
        parts.any(part => {
          part.is_empty() ||
          part.length() > 64 ||
          !part
          .to_owned()
          .all(c => c.is_ascii_alphabetic() || c.is_ascii_digit() || c == '_')
        }) {
        raise InvalidInput("Invalid field selector")
      }
      if !fields.contains(field) {
        fields.push(field)
      }
      if fields.length() > 32 {
        raise InvalidInput("Too many field selectors")
      }
    }
  }
  fields
}

///|
fn rest_project(value : Json, fields : Array[String]) -> Json {
  match value {
    Array(items) => items.map(item => rest_project(item, fields)).to_json()
    Object(properties) => {
      let projected : Map[String, Json] = Map([])
      for key, value in properties {
        if fields.contains(key) {
          projected[key] = value
          continue
        }
        let nested = fields.filter_map(field => {
          if field.has_prefix(key + ".") {
            Some(field[key.length() + 1:].to_owned())
          } else {
            None
          }
        })
        if !nested.is_empty() {
          projected[key] = rest_project(value, nested)
        }
      }
      Json::object(projected)
    }
    _ => value
  }
}

///|
test "REST field projection cannot invent fields outside authorization context" {
  let public : Json = { "id": 1, "title": { "rendered": "Public" } }
  let selected = rest_project(public, rest_fields(Some("id,title.raw")))
  assert_eq(selected.stringify(), "{\"id\":1,\"title\":{}}")
  assert_eq(
    rest_project(public, rest_fields(Some("missing"))).stringify(),
    "{}",
  )
  assert_eq(rest_project(public, rest_fields(Some("title,title.rendered"))), {
    "title": { "rendered": "Public" },
  })
  for invalid in ["title..raw", ".id", "id,", "id/x", "a.b.c.d.e.f.g.h.i"] {
    let rejected = try {
      rest_fields(Some(invalid)) |> ignore
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}
