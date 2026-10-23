///|
priv struct RestReservation {
  schema : Int
  sequence : Int
  previous : String
  id : Int
} derive(ToJson, FromJson)

///|
fn rest_reserve_id(
  input : String,
  content : AuthoringDirectory,
  minimum : Int,
) -> Int raise {
  let mut highest = minimum
  if path_kind(input + "/.moonpress-trash") != 0 {
    let trash = open_authoring_subdirectory(input, ".moonpress-trash")
    defer directory_close(trash.fd)
    require_same_authoring_site(content, trash)
    trash.lock()
    let names = @fs.read_dir(trash.path).to_owned()
    if names.length() > 4096 {
      raise InvalidInput("Trash scan exceeds limit")
    }
    let mut total = 0
    for name in names {
      let record = read_authoring_record(trash, name)
      total += @utf8.encode(record.content).length()
      if total > 16777216 {
        raise InvalidInput("Trash source scan exceeds limit")
      }
      let document = parse_document(record.content, name)
      highest = if highest > document.wp_id.unwrap_or(0) {
        highest
      } else {
        document.wp_id.unwrap_or(0)
      }
    }
  }
  prepare_authoring_vault(input, ".moonpress-identities") |> ignore
  let vault = open_authoring_subdirectory(input, ".moonpress-identities")
  defer directory_close(vault.fd)
  require_same_authoring_site(content, vault)
  vault.lock()
  let names = @fs.read_dir(vault.path).to_owned()
  if names.length() >= 4096 {
    raise InvalidInput("Identity reservation log is full")
  }
  names.sort()
  let mut sequence = 0
  let mut previous = "absent"
  let mut reserved = 0
  for name in names {
    sequence += 1
    if name != access_name(sequence) {
      raise InvalidInput("Identity log sequence rejected")
    }
    let file = directory_read(vault.fd, authoring_name(name))
    if io_is_null(file) != 0 {
      raise InvalidInput("Cannot open identity reservation")
    }
    if access_private_file(file) != 1 {
      io_close(file) |> ignore
      raise InvalidInput(
        "Identity reservation must be owner-only and unlinked elsewhere",
      )
    }
    let bytes = read_opened_file(file, name, max_bytes=1024)
    let value = @json.parse(decode_text(bytes, name))
    strict_json_object(
      value,
      ["schema", "sequence", "previous", "id"],
      "identity reservation",
    )
    |> ignore
    let record : RestReservation = @json.from_json(value)
    if record.schema != 1 ||
      record.sequence != sequence ||
      record.previous != previous ||
      record.id <= reserved {
      raise InvalidInput("Identity reservation chain rejected")
    }
    reserved = record.id
    previous = digest_bytes(bytes)
  }
  highest = if highest > reserved { highest } else { reserved }
  if highest >= 2147483647 {
    raise InvalidInput("Identity range exhausted")
  }
  let id = highest + 1
  let record : RestReservation = {
    schema: 1,
    sequence: sequence + 1,
    previous,
    id,
  }
  vault.write_new(
    access_name(record.sequence),
    @utf8.encode(ToJson::to_json(record).stringify() + "\n"),
    private_mode=true,
  )
  id
}
