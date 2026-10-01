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
  write_opened_file(open_file(path, 1), path, bytes)
}

///|
// Takes ownership of the stream and closes it on every success/error path.
fn write_opened_file(
  file : NativeFile,
  path : String,
  bytes : Bytes,
  mode_source? : String? = None,
) -> Unit raise {
  let mut closed = false
  defer (if !closed { io_close(file) |> ignore })
  if mode_source is Some(source) {
    if io_copy_mode(file, @utf8.encode(source) + b"\x00") != 0 {
      raise io_failure("copy permissions", path)
    }
  }
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

///|
#borrow(path)
extern "C" fn native_path_kind(path : Bytes) -> Int = "moonpress_path_kind"

///|
fn path_kind(path : String) -> Int raise {
  if path.contains("\u0000") {
    raise InvalidInput("NUL in filesystem path")
  }
  native_path_kind(@utf8.encode(path) + b"\x00")
}

///|
fn require_input_kind(path : String, expected : Int) -> Unit raise {
  if path_kind(path) != expected {
    let kind = if expected == 2 { "directory" } else { "file" }
    raise InvalidInput(
      "Expected regular input " +
      kind +
      " (no symlinks or special files): " +
      path,
    )
  }
}

///|
#borrow(path)
extern "C" fn io_copy_mode(file : NativeFile, path : Bytes) -> Int = "moonpress_io_copy_mode"
