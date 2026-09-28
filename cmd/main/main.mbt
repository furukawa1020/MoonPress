///|
priv struct ReportEnvelope {
  schema : Int
  command : String
  include_drafts : Bool
  report : Json
} derive(ToJson)

///|
fn print_report(command : String, include_drafts : Bool, report : Json) -> Unit {
  let envelope : ReportEnvelope = {
    schema: 1,
    command,
    include_drafts,
    report,
  }
  println(ToJson::to_json(envelope).stringify())
}

///|
fn main {
  let args = @env.args()
  let usage = "Usage: moonpress <build|explain> <site-directory> <output-directory> [--include-drafts] [--json]\n       moonpress check <site-directory> [--include-drafts] [--json]\n       moonpress --version"
  if args.length() == 1 {
    println(usage)
    return
  }
  if args.length() == 2 && args[1] == "--version" {
    println("moonpress 0.1.0")
    return
  }
  let command = args[1]
  let required = if command == "check" { 3 } else { 4 }
  let mut valid = command == "check" ||
    command == "build" ||
    command == "explain"
  if args.length() < required {
    valid = false
  } else {
    for index = 2; index < required; index = index + 1 {
      if args[index].has_prefix("--") {
        valid = false
      }
    }
  }
  let mut include_drafts = false
  let mut json = false
  for index = required; index < args.length(); index = index + 1 {
    match args[index] {
      "--include-drafts" if !include_drafts => include_drafts = true
      "--json" if !json => json = true
      _ => valid = false
    }
  }
  if !valid {
    eprintln(usage)
    @sys.exit(2)
    return
  }
  try {
    if command == "check" {
      let report = @lib.check_site(args[2], include_drafts~)
      if json {
        print_report(command, include_drafts, report.to_json())
      } else {
        println(
          "Checked: \{report.pages} pages, \{report.outputs} outputs; no files written",
        )
      }
    } else {
      let report = @lib.compile_site(
        args[2],
        args[3],
        dry_run=command == "explain",
        include_drafts~,
      )
      if json {
        print_report(command, include_drafts, report.to_json())
      } else {
        for event in report.events {
          println(event)
        }
        println(
          "Pages: \{report.pages}, written: \{report.written}, kept: \{report.skipped}, deleted: \{report.deleted}",
        )
      }
    }
  } catch {
    error => {
      eprintln("moonpress: \{error}")
      @sys.exit(1)
    }
  }
}
