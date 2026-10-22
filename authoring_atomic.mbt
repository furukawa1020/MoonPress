///|
extern "C" fn directory_anonymous(fd : Int) -> NativeFile = "moonpress_dir_anonymous"

///|
extern "C" fn io_duplicate(file : NativeFile) -> Int = "moonpress_io_duplicate"

///|
#borrow(name)
extern "C" fn directory_install(fd : Int, source : Int, name : Bytes) -> Int = "moonpress_dir_install"

///|
fn AuthoringDirectory::write_new(
  self : AuthoringDirectory,
  name : String,
  bytes : Bytes,
  private_mode? : Bool = false,
) -> Unit raise {
  let encoded = authoring_name(name)
  let path = self.path + "/" + name
  if self.kind(name) != 0 {
    raise InvalidInput("Authoring target already exists: " + path)
  }
  let file = directory_anonymous(self.fd)
  if io_is_null(file) != 0 {
    raise io_failure(
      "anonymous authoring open (filesystem must support O_TMPFILE)", path,
    )
  }
  if private_mode && io_private(file) != 0 {
    let error = io_failure("restrict backup permissions", path)
    io_close(file) |> ignore
    raise error
  }
  // Retain the anonymous inode while checking fclose before publication.
  let source = io_duplicate(file)
  if source < 0 {
    let error = io_failure("retain anonymous authoring inode", path)
    io_close(file) |> ignore
    raise error
  }
  defer atomic_parent_close(source) |> ignore
  write_opened_file(file, path, bytes, durable=true)
  if directory_install(self.fd, source, encoded) != 0 {
    raise io_failure("exclusive anonymous authoring install", path)
  }
  self.sync() catch {
    error =>
      raise InvalidInput(
        "Creation is visible, but durability is unconfirmed; reload and inspect " +
        path +
        ": \{error}",
      )
  }
}

///|
extern "C" fn io_private(file : NativeFile) -> Int = "moonpress_io_private"
