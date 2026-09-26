///|
fn main {
  let args = @env.args()
  if args.length() == 2 && args[1] == "--version" {
    println("moonpress 0.1.0")
  } else if args.length() == 4 && args[1] == "build" {
    try {
      let count = @lib.build_site(args[2], args[3])
      println("Built \{count} pages → \{args[3]}")
    } catch {
      error => {
        eprintln("moonpress: \{error}")
        @sys.exit(1)
      }
    }
  } else {
    let usage = "Usage: moonpress build <site-directory> <new-output-directory>\n       moonpress --version"
    if args.length() == 1 {
      println(usage)
    } else {
      eprintln(usage)
      @sys.exit(2)
    }
  }
}
