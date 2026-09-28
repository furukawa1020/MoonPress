///|
fn main {
  let args = @env.args()
  if args.length() == 2 && args[1] == "--version" {
    println("moonpress 0.1.0")
  } else if (
      args.length() == 3 ||
      (args.length() == 4 && args[3] == "--include-drafts")
    ) &&
    args[1] == "check" &&
    !args[2].has_prefix("--") {
    try {
      let report = @lib.check_site(args[2], include_drafts=args.length() == 4)
      println(
        "Checked: \{report.pages} pages, \{report.outputs} outputs; no files written",
      )
    } catch {
      error => {
        eprintln("moonpress: \{error}")
        @sys.exit(1)
      }
    }
  } else if (
      args.length() == 4 ||
      (args.length() == 5 && args[4] == "--include-drafts")
    ) &&
    (args[1] == "build" || args[1] == "explain") &&
    !args[2].has_prefix("--") &&
    !args[3].has_prefix("--") {
    try {
      let report = @lib.compile_site(
        args[2],
        args[3],
        dry_run=args[1] == "explain",
        include_drafts=args.length() == 5,
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
    let usage = "Usage: moonpress <build|explain> <site-directory> <output-directory> [--include-drafts]\n       moonpress check <site-directory> [--include-drafts]\n       moonpress --version"
    if args.length() == 1 {
      println(usage)
    } else {
      eprintln(usage)
      @sys.exit(2)
    }
  }
}
