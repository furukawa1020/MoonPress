///|
#borrow(source, target)
extern "C" fn native_replace_file(source : Bytes, target : Bytes) -> Int = "moonpress_replace_file"

///|
fn replace_staged_file(source : String, target : String) -> Unit raise {
  let result = native_replace_file(
    @utf8.encode(source) + b"\x00",
    @utf8.encode(target) + b"\x00",
  )
  if result != 0 {
    raise InvalidInput(
      "Cannot replace staged file " + target + " (errno \{result})",
    )
  }
}

///|
#borrow(source, target)
extern "C" fn native_link_file(source : Bytes, target : Bytes) -> Int = "moonpress_link_file"

///|
fn backup_file(
  output : String,
  backup : String,
  name : String,
  backed : Array[String],
) -> Unit raise {
  let source = output + "/" + name
  if path_kind(source) == 0 {
    return
  }
  if path_kind(source) != 1 {
    raise InvalidInput("Cannot back up non-regular output: " + source)
  }
  let result = native_link_file(
    @utf8.encode(source) + b"\x00",
    @utf8.encode(backup + "/" + name) + b"\x00",
  )
  if result != 0 {
    raise InvalidInput(
      "Cannot preserve output before publication: " +
      source +
      " (errno \{result})",
    )
  }
  backed.push(name)
}

///|
fn rollback_publication(
  output : String,
  backup : String,
  applied : Array[String],
  backed : Array[String],
) -> Unit raise {
  let preserved : Map[String, Bool] = Map([])
  for name in backed {
    preserved[name] = true
  }
  for index = applied.length() - 1; index >= 0; index = index - 1 {
    let name = applied[index]
    if preserved.contains(name) {
      replace_staged_file(backup + "/" + name, output + "/" + name)
    } else {
      // Only successful writes from this invocation can appear without a backup.
      let path = output + "/" + name
      match path_kind(path) {
        0 => ()
        1 => @fs.remove_file(path)
        _ => raise InvalidInput("Cannot roll back non-regular output: " + path)
      }
    }
  }
}
