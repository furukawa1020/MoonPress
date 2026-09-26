///|
fn main {
  let args = @env.args()
  if args.length() == 2 && args[1] == "--version" {
    println("moonpress 0.1.0")
  } else if args.length() == 4 && (args[1] == "build" || args[1] == "explain") {
    try {
      let report = @lib.compile_site(
        args[2],
        args[3],
        dry_run=args[1] == "explain",
      )
      for event in report.events {
        println(event)
      }
      println(
        "Pages: \{report.pages}, written: \{report.written}, kept: \{report.skipped}, deleted: \{report.deleted}",
      )
    } catch {
      error => {
        eprintln("moonpress: \{error}")
        @sys.exit(1)
      }
    }
  } else {
    let usage = "Usage: moonpress <build|explain> <site-directory> <output-directory>\n       moonpress --version"
    if args.length() == 1 {
      println(usage)
    } else {
      eprintln(usage)
      @sys.exit(2)
    }
  }
}
