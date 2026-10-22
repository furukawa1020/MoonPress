///|
#borrow(name)
extern "C" fn directory_prepare_private(fd : Int, name : Bytes) -> Int = "moonpress_dir_prepare_private"

///|
fn prepare_authoring_vault(input : String, name : String) -> Bool raise {
  if input.is_empty() {
    raise InvalidInput("Site directory must not be empty")
  }
  if name != ".moonpress-history" &&
    name != ".moonpress-trash" &&
    name != ".moonpress-access" {
    raise InvalidInput("Unknown private authoring vault")
  }
  require_input_kind(input + "/content", 2)
  let root = open_authoring_directory(input)
  defer directory_close(root.fd)
  root.lock()
  let result = directory_prepare_private(root.fd, authoring_name(name))
  if result < 0 {
    raise InvalidInput(
      "Private vault must be a real owner-only directory; preserve any existing entry: " +
      input +
      "/" +
      name,
    )
  }
  result == 0
}

///|
pub fn enable_post_history(input : String) -> Bool raise {
  prepare_authoring_vault(input, ".moonpress-history")
}
