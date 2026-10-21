///|
#borrow(path, buffer)
extern "C" fn resolve_output_path(
  path : Bytes,
  buffer : Bytes,
  capacity : Int,
) -> Int = "moonpress_resolve_output"

///|
fn recovery_record_path(output : String) -> String raise {
  let buffer = Bytes::make(4096, 0)
  if resolve_output_path(@utf8.encode(output) + b"\x00", buffer, 4096) != 0 {
    raise InvalidInput("Cannot resolve recovery record path: " + output)
  }
  let canonical = decode_text(buffer, output)
    .split("\u0000")
    .next()
    .unwrap()
    .to_owned()
  let parts = canonical.split("/").map(part => part.to_owned()).to_array()
  let name = parts.pop().unwrap()
  parts.join("/") + "/.moonpress-recovery-" + digest_text(name) + ".json"
}

///|
fn retain_recovery_record(output : String, stage : String) -> Unit raise {
  let record = recovery_record_path(output)
  if path_kind(record) != 0 {
    raise InvalidInput(
      "Recovery record already exists; run recovery first: " + record,
    )
  }
  let source = stage + "/journal"
  parse_journal(read_publication_text(source, 64 * 1024 * 1024)) |> ignore
  let result = native_link_file(
    @utf8.encode(source) + b"\x00",
    @utf8.encode(record) + b"\x00",
  )
  if result != 0 {
    raise InvalidInput(
      "Cannot retain recovery record (errno \{result}): " + record,
    )
  }
}
