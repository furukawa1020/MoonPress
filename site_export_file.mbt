///|
extern "C" fn directory_same(a : Int, b : Int) -> Int = "moonpress_dir_same"

///|
extern "C" fn directory_within(directory : Int, root : Int) -> Int = "moonpress_dir_within"

///|
#borrow(path)
extern "C" fn input_directory_open(path : Bytes) -> Int = "moonpress_input_directory_open"

///|
pub fn export_site_to_file(
  input : String,
  output : String,
  expected_review : String,
  archive : String,
) -> SiteExportReport raise {
  let parts = archive.split("/").map(part => part.to_owned()).to_array()
  let name = parts[parts.length() - 1]
  if !safe_output_name(name) || name.has_prefix(".") || !name.has_suffix(".zip") {
    raise InvalidInput("Export destination must be a new visible .zip filename")
  }
  let parent = if parts.length() == 1 {
    "."
  } else {
    parts.pop() |> ignore
    let path = parts.join("/")
    if path.is_empty() {
      "/"
    } else {
      path
    }
  }
  let directory = open_authoring_directory(parent)
  defer directory_close(directory.fd)
  let source = open_authoring_directory(normalize_output(output))
  defer directory_close(source.fd)
  if directory_same(directory.fd, source.fd) != 0 {
    raise InvalidInput("Save the ZIP outside the managed production output")
  }
  if input.is_empty() || input.contains("\u0000") {
    raise InvalidInput("Invalid source site directory")
  }
  let trimmed = input.trim_end(chars="/").to_owned()
  let root = if trimmed.is_empty() { "/" } else { trimmed }
  require_input_kind(root, 2)
  let project = input_directory_open(@utf8.encode(root) + b"\x00")
  if project < 0 {
    raise io_failure("source directory identity", root)
  }
  defer directory_close(project)
  if directory_within(directory.fd, project) != 0 {
    raise InvalidInput("Save the ZIP outside the source site directory")
  }
  let snapshot = export_site(input, output, expected_review)
  directory.lock()
  if directory.kind(name) != 0 {
    raise InvalidInput("Export destination already exists: " + archive)
  }
  require_input_kind(root, 2)
  let current_project = input_directory_open(@utf8.encode(root) + b"\x00")
  if current_project < 0 {
    raise io_failure("source directory recheck", root)
  }
  defer directory_close(current_project)
  if directory_same(project, current_project) != 1 ||
    directory_within(directory.fd, current_project) != 0 {
    raise InvalidInput("Source directory changed; review export again")
  }
  let file = directory.create(name)
  directory.write(file, name, snapshot.content, None) catch {
    error => {
      let cleanup = try {
        directory.require_file(name)
        directory.remove(name)
        ""
      } catch {
        cause => "; cleanup incomplete; inspect " + archive + ": \{cause}"
      }
      raise InvalidInput("Export write failed: \{error}" + cleanup)
    }
  }
  snapshot.report
}
