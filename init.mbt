///|
pub(all) struct InitReport {
  directory : String
  files : Array[String]
} derive(ToJson)

///|
pub extend InitReport with ToJson::{to_json}

///|
pub fn init_site(directory : String) -> InitReport raise {
  let directory = directory.trim_end(chars="/").to_owned()
  if directory.is_empty() {
    raise InvalidInput("New site directory must not be empty or root")
  }
  if path_kind(directory) != 0 {
    raise InvalidInput("Site target must not exist: " + directory)
  }
  let lock = lock_output(directory, shared=false)
  defer native_unlock_output(lock)
  if path_kind(directory) != 0 {
    raise InvalidInput("Site target must not exist: " + directory)
  }
  // Exclusive mkdir establishes ownership. Never clean up a pre-existing target.
  @fs.create_dir(directory)
  let directories : Array[String] = []
  let files : Array[String] = []
  try {
    for name in ["content", "layouts"] {
      @fs.create_dir(directory + "/" + name)
      directories.push(name)
    }
    for (name, content) in starter_files() {
      // A failed write may have created a partial file, so record it first.
      files.push(name)
      write_text(directory + "/" + name, content)
    }
  } catch {
    error => {
      let cleanup = try {
        cleanup_init(directory, files, directories)
        ""
      } catch {
        cause => "; cleanup incomplete; inspect " + directory + ": \{cause}"
      }
      raise InvalidInput("Site initialization failed: \{error}" + cleanup)
    }
  }
  { directory, files, }
}

///|
fn cleanup_init(
  directory : String,
  files : Array[String],
  directories : Array[String],
) -> Unit raise {
  for name in files {
    let path = directory + "/" + name
    match path_kind(path) {
      0 => ()
      1 => @fs.remove_file(path)
      _ => raise InvalidInput("Refusing non-regular starter file: " + path)
    }
  }
  for i = directories.length() - 1; i >= 0; i = i - 1 {
    // rmdir refuses unexpected contents; never recursively delete an input tree.
    @fs.remove_dir(directory + "/" + directories[i])
  }
  @fs.remove_dir(directory)
}
