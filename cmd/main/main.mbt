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
fn is_help(value : String) -> Bool {
  value == "--help" || value == "-h"
}

///|
fn is_command(value : String) -> Bool {
  value == "build" || value == "check" || value == "explain"
}

///|
fn usage(command : String) -> String {
  match command {
    "build" =>
      "Usage: moonpress build <site-directory> <output-directory> [--include-drafts] [--json]"
    "explain" =>
      "Usage: moonpress explain <site-directory> <output-directory> [--include-drafts] [--json]"
    "check" =>
      "Usage: moonpress check <site-directory> [--include-drafts] [--json]"
    _ =>
      "Usage: moonpress <build|explain> <site-directory> <output-directory> [--include-drafts] [--json]\n       moonpress check <site-directory> [--include-drafts] [--json]\n       moonpress [--help|-h|--version]\n       moonpress <build|check|explain> [--help|-h]"
  }
}

///|
fn help_text(command : String) -> String {
  let description = match command {
    "build" =>
      "Compile the site and update a new or MoonPress-managed output directory.\nRefuse unmanaged files, edited output and symlinks before publication."
    "check" =>
      "Compile and validate sources in memory; no output directory is needed.\nWrite no generated files; existing output directories are not inspected."
    "explain" =>
      "Validate the site/output and report planned incremental changes.\nDry run: no files or directories are written."
    _ =>
      "MoonPress: a native MoonBit static-site compiler.\n\nCommands:\n  build    Compile and update a new or MoonPress-managed output directory.\n  check    Validate sources in memory without writing generated files.\n  explain  Report planned changes without writing files or directories."
  }
  description +
  "\n\n" +
  usage(command) +
  "\n\nOptions (after directory arguments; each at most once, in either order):\n  --json            Print one schema-1 JSON report on success.\n  --include-drafts  Include drafts; build output WILL contain draft pages.\n                    Use a separate preview directory instead of deployed output.\n\nHelp: moonpress --help or moonpress <command> --help (also -h).\nVersion: moonpress --version. Help/version cannot be combined with other options.\n\nExit status: 0 success, 1 validation/I/O failure, 2 incorrect arguments.\nErrors go to stderr; stdout is empty on failure."
}

///|
fn main {
  let args = @env.args()
  if args.length() == 1 || (args.length() == 2 && is_help(args[1])) {
    println(help_text(""))
    return
  }
  if args.length() == 3 && is_command(args[1]) && is_help(args[2]) {
    println(help_text(args[1]))
    return
  }
  if args.length() == 2 && args[1] == "--version" {
    println("moonpress 0.1.0")
    return
  }
  let command = args[1]
  let required = if command == "check" { 3 } else { 4 }
  let mut valid = is_command(command)
  if args.length() < required {
    valid = false
  } else {
    for index = 2; index < required; index = index + 1 {
      if args[index].has_prefix("--") || is_help(args[index]) {
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
    eprintln(usage(""))
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
