///|
priv struct AuthoringDirectory {
  fd : Int
  path : String
}

///|
#borrow(path)
extern "C" fn directory_open(path : Bytes) -> Int = "moonpress_dir_open"

///|
extern "C" fn directory_close(fd : Int) -> Unit = "moonpress_dir_close"

///|
#borrow(name)
extern "C" fn directory_kind(fd : Int, name : Bytes) -> Int = "moonpress_dir_kind"

///|
#borrow(name)
extern "C" fn directory_read(fd : Int, name : Bytes) -> NativeFile = "moonpress_dir_read"

///|
fn open_authoring_directory(path : String) -> AuthoringDirectory raise {
  if path.contains("\u0000") {
    raise InvalidInput("NUL in directory path")
  }
  let fd = directory_open(@utf8.encode(path) + b"\x00")
  if fd < 0 {
    raise io_failure("guarded directory open", path)
  }
  { fd, path, }
}

///|
fn authoring_name(name : String) -> Bytes raise {
  if !safe_output_name(name) {
    raise InvalidInput("Invalid authoring filename")
  }
  @utf8.encode(name) + b"\x00"
}

///|
fn AuthoringDirectory::kind(
  self : AuthoringDirectory,
  name : String,
) -> Int raise {
  let kind = directory_kind(self.fd, authoring_name(name))
  if kind < 0 {
    raise io_failure("directory-relative stat", self.path + "/" + name)
  }
  kind
}

///|
fn AuthoringDirectory::read(
  self : AuthoringDirectory,
  name : String,
) -> Bytes raise {
  let file = directory_read(self.fd, authoring_name(name))
  let path = self.path + "/" + name
  if io_is_null(file) != 0 {
    raise io_failure("directory-relative read", path)
  }
  read_opened_file(file, path)
}
