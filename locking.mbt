///|
#borrow(path)
extern "C" fn native_lock_output(path : Bytes, shared : Int) -> Int = "moonpress_lock_output"

///|
extern "C" fn native_unlock_output(fd : Int) -> Unit = "moonpress_unlock_output"

///|
fn lock_output(output : String, shared~ : Bool) -> Int raise {
  if output.contains("\u0000") {
    raise InvalidInput("NUL in filesystem path")
  }
  let fd = native_lock_output(
    @utf8.encode(output) + b"\x00",
    if shared {
      1
    } else {
      0
    },
  )
  if fd == -2 {
    raise InvalidInput(
      "Output parent is busy with another MoonPress build, explain or recover; retry after it finishes: " +
      output,
    )
  }
  if fd < 0 {
    raise InvalidInput(
      "Cannot lock output parent (must exist, be readable, and support directory flock): " +
      output,
    )
  }
  fd
}
