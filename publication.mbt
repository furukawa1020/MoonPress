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
