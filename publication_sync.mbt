///|
fn sync_publication_file(path : String) -> Unit raise {
  let file = open_file(path, 0)
  let mut closed = false
  defer (if !closed { io_close(file) |> ignore })
  if atomic_sync(file) != 0 {
    raise io_failure("sync recovery file", path)
  }
  let result = io_close(file)
  closed = true
  if result != 0 {
    raise io_failure("close recovery file", path)
  }
}

///|
fn sync_publication_directory(
  path : String,
  parent? : Bool = false,
) -> Unit raise {
  if path.contains("\u0000") {
    raise InvalidInput("NUL in synchronization path")
  }
  let encoded = @utf8.encode(path) + b"\x00"
  let fd = if parent {
    atomic_parent_open(encoded)
  } else {
    directory_open(encoded)
  }
  if fd < 0 {
    raise io_failure("open recovery directory", path)
  }
  let mut closed = false
  defer (if !closed { atomic_parent_close(fd) |> ignore })
  if atomic_parent_sync(fd) != 0 {
    raise io_failure("sync recovery directory", path)
  }
  let result = atomic_parent_close(fd)
  closed = true
  if result != 0 {
    raise io_failure("close recovery directory", path)
  }
}
