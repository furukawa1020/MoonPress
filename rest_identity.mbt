///|
pub fn save_post_identity(
  input : String,
  name : String,
  expected : String,
  id : String,
  author : String,
) -> SavePostReport raise {
  let id = rest_positive(id, 2147483647)
  let author = if author == "0" { 0 } else { rest_positive(author, 2147483647) }
  let snapshot = read_post(input, name)
  require_post_version(snapshot, expected)
  let document = parse_document(snapshot.content, name)
  if document.wp_id is Some(previous) && previous != id {
    raise InvalidInput("An assigned REST identity cannot be renumbered")
  }
  if document.wp_id == Some(id) && document.author == author {
    return save_post(input, name, expected, snapshot.content)
  }
  let (metadata, body) = document_parts(snapshot.content, name)
  let fields = match metadata {
    Object(fields) => fields
    _ => raise InvalidInput("Frontmatter must be an object")
  }
  fields["wp_id"] = id.to_json()
  fields["author"] = author.to_json()
  save_post(
    input,
    name,
    expected,
    "---\n" + metadata.stringify() + "\n---\n" + body,
  )
}

///|
fn rest_positive(value : String, maximum : Int) -> Int raise {
  if value.is_empty() ||
    value.length() > 10 ||
    value.has_prefix("0") ||
    !value.all(c => c.is_ascii_digit()) {
    raise InvalidInput("Expected canonical positive integer")
  }
  let mut result = 0L
  for c in value {
    result = result * 10L + (c.to_int() - 48).to_int64()
  }
  if result > maximum.to_int64() {
    raise InvalidInput("Integer exceeds limit")
  }
  result.to_int()
}

///|
fn rest_basic(value : String) -> (String, String) raise {
  if value.length() < 6 || value[:6].to_owned().to_lower() != "basic " {
    raise InvalidInput("Basic credential required")
  }
  let value = value[6:].to_owned()
  if value.is_empty() || value.length() > 172 || value.length() % 4 != 0 {
    raise InvalidInput("Invalid Basic encoding")
  }
  let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  let out = StringBuilder()
  for i = 0; i < value.length(); i = i + 4 {
    let values : Array[Int] = []
    for j = 0; j < 4; j = j + 1 {
      let c = value[i + j]
      if c == '=' && i + 4 == value.length() && j >= 2 {
        values.push(-1)
      } else {
        let mut decoded = -1
        for k = 0; k < 64; k = k + 1 {
          if alphabet[k] == c {
            decoded = k
          }
        }
        if decoded < 0 {
          raise InvalidInput("Invalid Basic alphabet")
        }
        values.push(decoded)
      }
    }
    if (values[2] < 0 && (values[3] >= 0 || values[1] % 16 != 0)) ||
      (values[3] < 0 && values[2] >= 0 && values[2] % 4 != 0) {
      raise InvalidInput("Noncanonical Basic padding")
    }
    let bytes = [values[0] * 4 + values[1] / 16]
    if values[2] >= 0 {
      bytes.push(values[1] % 16 * 16 + values[2] / 4)
    }
    if values[3] >= 0 {
      bytes.push(values[2] % 4 * 64 + values[3])
    }
    for byte in bytes {
      if byte < 33 || byte > 126 {
        raise InvalidInput("Non-ASCII Basic credential")
      }
      out.write_char(byte.unsafe_to_char())
    }
  }
  let (login, secret) = match out.to_string().split_once(":") {
    Some((login, secret)) => (login.to_owned(), secret.to_owned())
    None => raise InvalidInput("Missing Basic separator")
  }
  access_login(login)
  if !valid_digest(secret) {
    raise InvalidInput("Invalid application secret format")
  }
  (login, secret)
}
