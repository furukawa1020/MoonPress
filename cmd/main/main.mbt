///|
fn main raise {
  let args = @env.args()
  if args.length() == 2 && args[1] == "--version" {
    println("moonpress 0.1.0")
  } else if args.length() == 4 && args[1] == "build" {
    let count = @lib.build_site(args[2], args[3])
    println("Built \{count} pages → \{args[3]}")
  } else {
    println("Usage: moonpress build <site-directory> <new-output-directory>")
    println("       moonpress --version")
    if args.length() != 1 {
      abort("Invalid arguments")
    }
  }
}
