///|
fn AuthoringDirectory::names(self : AuthoringDirectory) -> Array[String] raise {
  // Linux /proc opens the retained directory inode, independent of its pathname.
  let names = @fs.read_dir("/proc/self/fd/" + self.fd.to_string()).to_owned()
  if names.length() > 4096 {
    raise InvalidInput("Retained directory entry limit")
  }
  names.sort()
  names
}
