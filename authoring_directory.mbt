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

///|
extern "C" fn directory_lock(fd : Int) -> Int = "moonpress_dir_lock"

///|
#borrow(name)
extern "C" fn directory_create(fd : Int, name : Bytes) -> NativeFile = "moonpress_dir_create"

///|
#borrow(name)
extern "C" fn directory_copy_mode(
  fd : Int,
  file : NativeFile,
  name : Bytes,
) -> Int = "moonpress_dir_copy_mode"

///|
#borrow(stage, target)
extern "C" fn directory_publish(
  fd : Int,
  stage : Bytes,
  target : Bytes,
  exclusive : Int,
) -> Int = "moonpress_dir_publish"

///|
#borrow(name)
extern "C" fn directory_remove(fd : Int, name : Bytes) -> Int = "moonpress_dir_remove"

///|
fn AuthoringDirectory::lock(self : AuthoringDirectory) -> Unit raise {
  let result = directory_lock(self.fd)
  if result == -2 {
    raise InvalidInput(
      "Directory is busy with another MoonPress operation: " + self.path,
    )
  }
  if result != 0 {
    raise io_failure("directory lock", self.path)
  }
}

///|
fn AuthoringDirectory::create(
  self : AuthoringDirectory,
  name : String,
) -> NativeFile raise {
  let file = directory_create(self.fd, authoring_name(name))
  if io_is_null(file) != 0 {
    raise io_failure(
      "exclusive staging open; inspect any remnant",
      self.path + "/" + name,
    )
  }
  file
}

///|
fn AuthoringDirectory::write(
  self : AuthoringDirectory,
  file : NativeFile,
  name : String,
  bytes : Bytes,
  mode_source : String?,
) -> Unit raise {
  // Transfer stream ownership only after permission copying succeeds.
  let mut transferred = false
  defer (if !transferred { io_close(file) |> ignore })
  if mode_source is Some(source) {
    if directory_copy_mode(self.fd, file, authoring_name(source)) != 0 {
      raise io_failure("copy permissions", self.path + "/" + name)
    }
  }
  transferred = true
  write_opened_file(file, self.path + "/" + name, bytes, durable=true)
}

///|
fn AuthoringDirectory::publish(
  self : AuthoringDirectory,
  stage : String,
  target : String,
  exclusive : Bool,
) -> Unit raise {
  if directory_publish(
      self.fd,
      authoring_name(stage),
      authoring_name(target),
      if exclusive {
        1
      } else {
        0
      },
    ) !=
    0 {
    raise io_failure("directory-relative publication", self.path + "/" + target)
  }
}

///|
fn AuthoringDirectory::sync(self : AuthoringDirectory) -> Unit raise {
  if atomic_parent_sync(self.fd) != 0 {
    raise io_failure("sync authoring directory", self.path)
  }
}

///|
fn AuthoringDirectory::remove(
  self : AuthoringDirectory,
  name : String,
) -> Unit raise {
  if directory_remove(self.fd, authoring_name(name)) != 0 {
    raise io_failure("directory-relative cleanup", self.path + "/" + name)
  }
  self.sync() catch {
    error =>
      raise InvalidInput(
        "Removal is visible, but durability is unconfirmed; reload and inspect " +
        self.path +
        "/" +
        name +
        ": \{error}",
      )
  }
}

///|
fn AuthoringDirectory::require_file(
  self : AuthoringDirectory,
  name : String,
) -> Unit raise {
  if self.kind(name) != 1 {
    raise InvalidInput(
      "Expected regular authoring file: " + self.path + "/" + name,
    )
  }
}

///|
fn open_authoring_subdirectory(
  input : String,
  child : String,
) -> AuthoringDirectory raise {
  if input.is_empty() {
    raise InvalidInput("Site directory must not be empty")
  }
  authoring_name(child) |> ignore
  open_authoring_directory(input + "/" + child)
}
