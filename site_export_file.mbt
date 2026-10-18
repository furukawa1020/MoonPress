///|
extern "C" fn directory_same(a : Int, b : Int) -> Int = "moonpress_dir_same"

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
  let snapshot = export_site(input, output, expected_review)
  directory.lock()
  if directory.kind(name) != 0 {
    raise InvalidInput("Export destination already exists: " + archive)
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
