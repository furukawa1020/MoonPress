///|
#external
priv type NativeFile

///|
#borrow(path)
extern "C" fn io_open(path : Bytes, write_mode : Int) -> NativeFile = "moonpress_io_open"

///|
extern "C" fn io_is_null(file : NativeFile) -> Int = "moonpress_io_is_null"

///|
#borrow(data)
extern "C" fn io_write(file : NativeFile, data : Bytes, length : Int) -> Int = "moonpress_io_write"

///|
extern "C" fn io_flush(file : NativeFile) -> Int = "moonpress_io_flush"

///|
extern "C" fn io_close(file : NativeFile) -> Int = "moonpress_io_close"

///|
extern "C" fn io_errno() -> Int = "moonpress_io_errno"

///|
fn io_failure(operation : String, path : String) -> BuildError {
  let code = io_errno()
  InvalidInput("File " + operation + " failed: " + path + " (errno \{code})")
}

///|
fn open_file(path : String, write_mode : Int) -> NativeFile raise {
  if path.contains("\u0000") {
    raise InvalidInput("NUL in filesystem path")
  }
  let file = io_open(@utf8.encode(path) + b"\x00", write_mode)
  if io_is_null(file) != 0 {
    raise io_failure("open", path)
  }
  file
}

///|
fn write_bytes(path : String, bytes : Bytes) -> Unit raise {
  let file = open_file(path, 1)
  let mut closed = false
  defer (if !closed { io_close(file) |> ignore })
  if io_write(file, bytes, bytes.length()) != bytes.length() {
    raise io_failure("write", path)
  }
  if io_flush(file) != 0 {
    raise io_failure("flush", path)
  }
  // fclose consumes the handle even when it reports an error. Never retry it.
  let result = io_close(file)
  closed = true
  if result != 0 {
    raise io_failure("close", path)
  }
}

///|
fn write_text(path : String, text : String) -> Unit raise {
  write_bytes(path, @utf8.encode(text))
}

///|
extern "C" fn io_seek(file : NativeFile, whence : Int) -> Int = "moonpress_io_seek"

///|
extern "C" fn io_size(file : NativeFile) -> Int64 = "moonpress_io_size"

///|
#borrow(data)
extern "C" fn io_read(file : NativeFile, data : Bytes, length : Int) -> Int = "moonpress_io_read"

///|
fn read_bytes(path : String) -> Bytes raise {
  let file = open_file(path, 0)
  let mut closed = false
  defer (if !closed { io_close(file) |> ignore })
  if io_seek(file, 2) != 0 {
    raise io_failure("seek", path)
  }
  let size = io_size(file)
  if size < 0 {
    raise io_failure("size", path)
  }
  if size > 2147483647L {
    raise InvalidInput("File exceeds supported byte-buffer length: " + path)
  }
  if io_seek(file, 0) != 0 {
    raise io_failure("rewind", path)
  }
  let bytes = Bytes::make(size.to_int(), 0)
  if io_read(file, bytes, bytes.length()) != bytes.length() {
    raise io_failure("read (short input)", path)
  }
  let result = io_close(file)
  closed = true
  if result != 0 {
    raise io_failure("close", path)
  }
  bytes
}

///|
fn decode_text(bytes : Bytes, path : String) -> String raise {
  @utf8.decode(bytes, ignore_bom=false) catch {
    _ => raise InvalidInput("Invalid UTF-8 text: " + path)
  }
}

///|
fn read_text(path : String) -> String raise {
  // The descriptor is already closed before decoding can raise.
  decode_text(read_bytes(path), path)
}
