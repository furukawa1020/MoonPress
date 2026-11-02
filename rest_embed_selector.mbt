///|
fn rest_embed_relations(value : String?) -> Array[String]? raise {
  match value {
    None => None
    Some(value) => {
      if value.length() > 1024 || value.any(c => c.is_control()) {
        raise InvalidInput("Embed selector limit")
      }
      if ["", "true", "1", "0"].contains(value) {
        return Some([])
      }
      let out : Array[String] = []
      let normalized = StringBuilder()
      for c in value {
        normalized.write_char(
          if c.is_whitespace() || c == ',' {
            ' '
          } else {
            c
          },
        )
      }
      for part in normalized.to_string().split(" ") {
        let rel = part.to_owned()
        if rel.is_empty() {
          continue
        }
        if rel.length() > 128 ||
          !rel.all(c => {
            c.is_ascii_alphabetic() ||
            c.is_ascii_digit() ||
            [':', '/', '_', '-', '.'].contains(c)
          }) {
          raise InvalidInput("Invalid embed relation")
        }
        if !out.contains(rel) {
          out.push(rel)
        }
        if out.length() > 16 {
          raise InvalidInput("Too many embed relations")
        }
      }
      Some(out)
    }
  }
}
