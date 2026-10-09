///|
pub fn prepare_media(input : String) -> Bool raise {
  require_input_kind(input, 2)
  require_input_kind(input + "/content", 2)
  let directory = input + "/public"
  let lock = lock_output(directory, shared=false)
  defer native_unlock_output(lock)
  let kind = path_kind(directory)
  if kind == 2 {
    return false
  }
  if kind != 0 {
    raise InvalidInput(
      "Media storage must be a real directory, not an existing file or symlink",
    )
  }
  @fs.create_dir(directory)
  true
}
