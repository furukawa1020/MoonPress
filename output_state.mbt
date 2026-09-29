///|
fn load_previous(output : String) -> Map[String, Artifact] raise {
  let result : Map[String, Artifact] = Map([])
  let kind = path_kind(output)
  if kind == 0 {
    return result
  }
  if kind != 2 {
    raise InvalidInput("Output must be a real directory, not a symlink")
  }
  if path_kind(output + "/.moonpress-stage") != 0 {
    raise InvalidInput(
      "Output contains an unfinished or foreign staging entry; try moonpress recover or use a fresh output directory: " +
      output,
    )
  }
  let marker = output + "/.moonpress.json"
  if path_kind(marker) != 1 {
    raise InvalidInput("Existing output is not managed by MoonPress")
  }
  let state = parse_manifest(read_text(marker))
  for artifact in state.artifacts {
    result[artifact.name] = artifact
  }
  // Refuse unknown files and edited outputs before ANY writes or deletions.
  for name in @fs.read_dir(output) {
    let file = output + "/" + name
    if path_kind(file) != 1 {
      raise InvalidInput("Output contains a non-regular file: " + name)
    }
    if name != ".moonpress.json" {
      match result.get(name) {
        None => raise InvalidInput("Unmanaged output file: " + name)
        Some(artifact) =>
          if digest_bytes(read_bytes(file)) != artifact.digest {
            raise InvalidInput("Output was edited outside MoonPress: " + name)
          }
      }
    }
  }
  result
}
