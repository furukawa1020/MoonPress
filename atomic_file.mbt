///|
extern "C" fn atomic_sync(file : NativeFile) -> Int = "moonpress_io_sync"

///|
#borrow(path)
extern "C" fn atomic_open(path : Bytes) -> NativeFile = "moonpress_atomic_open"

///|
#borrow(path)
extern "C" fn atomic_install(file : NativeFile, path : Bytes) -> Int = "moonpress_atomic_install"

///|
fn write_atomic_new(path : String, bytes : Bytes) -> Unit raise {
  if path.contains("\u0000") {
    raise InvalidInput("NUL in filesystem path")
  }
  let encoded = @utf8.encode(path) + b"\x00"
  let file = atomic_open(encoded)
  if io_is_null(file) != 0 {
    raise io_failure("anonymous open", path)
  }
  let mut closed = false
  defer (if !closed { io_close(file) |> ignore })
  if io_write(file, bytes, bytes.length()) != bytes.length() {
    raise io_failure("write", path)
  }
  if io_flush(file) != 0 {
    raise io_failure("flush", path)
  }
  if atomic_sync(file) != 0 {
    raise io_failure("sync file", path)
  }
  if atomic_install(file, encoded) != 0 {
    raise io_failure("exclusive install", path)
  }
  let result = io_close(file)
  closed = true
  if result != 0 {
    @fs.remove_file(path)
    raise io_failure("close", path)
  }
}
