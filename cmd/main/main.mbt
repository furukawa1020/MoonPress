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
  value == "read" ||
  value == "save" ||
  value == "new" ||
  value == "posts" ||
  value == "init" ||
  value == "build" ||
  value == "check" ||
  value == "explain" ||
  value == "recover"
}

///|
fn usage(command : String) -> String {
  match command {
    "read" => "Usage: moonpress read <site-directory> <filename.md> [--json]"
    "save" =>
      "Usage: moonpress save <site-directory> <filename.md> <expected-digest> <replacement-file> [--json]"
    "new" => "Usage: moonpress new <site-directory> <slug> <title> [--json]"
    "posts" => "Usage: moonpress posts <site-directory> [--json]"
    "init" => "Usage: moonpress init <site-directory> [--json]"
    "recover" => "Usage: moonpress recover <output-directory> [--json]"
    "build" =>
      "Usage: moonpress build <site-directory> <output-directory> [--include-drafts] [--json]"
    "explain" =>
      "Usage: moonpress explain <site-directory> <output-directory> [--include-drafts] [--json]"
    "check" =>
      "Usage: moonpress check <site-directory> [--include-drafts] [--json]"
    _ =>
      "Usage: moonpress <build|explain> <site-directory> <output-directory> [--include-drafts] [--json]\n       moonpress check <site-directory> [--include-drafts] [--json]\n       moonpress init <site-directory> [--json]\n       moonpress recover <output-directory> [--json]\n       moonpress [--help|-h|--version]\n       moonpress <init|new|posts|read|save|build|check|explain|recover> [--help|-h]"
  }
}

///|
fn help_text(command : String) -> String {
  let description = match command {
    "read" =>
      "Read a post source and SHA-256 version for editing; no files written."
    "save" =>
      "Save validated replacement source only if the expected version matches.\nExisting source stays intact on caught preparation failures; no hosting action."
    "new" =>
      "Create content/<slug>.md as a draft with the supplied title.\nThe site/content directory must exist; existing targets are never overwritten.\nEdit the generated Markdown, then build a separate preview with --include-drafts."
    "posts" =>
      "List all Markdown posts, including drafts and unlisted pages.\nRead metadata only; no layout, output or deployment validation is performed.\nNo files are written. Draft status is not a record of deployment."
    "init" =>
      "Create a ready-to-build Markdown/HTML/CSS starter in a new directory.\nThe parent must exist; existing targets are never overwritten.\nNo network access, Git initialization or hosting setup is performed."
    "recover" =>
      "Recover interrupted publication using its validated staging journal.\nRestore the previous output before commit; finalize cleanup after commit.\nReject edited files and incomplete journals before any change. No site input needed."
    "build" =>
      "Compile the site and update a new or MoonPress-managed output directory.\nRefuse unmanaged files, edited output and symlinks before publication."
    "check" =>
      "Compile and validate sources in memory; no output directory is needed.\nWrite no generated files; existing output directories are not inspected."
    "explain" =>
      "Validate the site/output and report planned incremental changes.\nDry run: no files or directories are written."
    _ =>
      "MoonPress: a native MoonBit static-site compiler.\n\nCommands:\n  read     Read post source and version.\n  save     Save post source with stale-version protection.\n  new      Create a draft article without overwriting existing files.\n  posts    List posts and draft status without building.\n  init     Create a starter site in a new directory.\n  build    Compile and update a new or MoonPress-managed output directory.\n  check    Validate sources in memory without writing generated files.\n  explain  Report planned changes without writing files or directories.\n  recover  Recover a journaled interrupted publication without source input."
  }
  if command == "recover" ||
    command == "init" ||
    command == "posts" ||
    command == "new" ||
    command == "read" ||
    command == "save" {
    return description +
      "\n\n" +
      usage(command) +
      "\n\n--json prints one schema-1 report. No --include-drafts option.\nExit status: 0 success, 1 validation/I/O failure, 2 incorrect arguments.\nErrors go to stderr; stdout is empty on failure."
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
  let required = if command == "save" {
    6
  } else if command == "new" {
    5
  } else if command == "check" ||
    command == "recover" ||
    command == "init" ||
    command == "posts" {
    3
  } else {
    4
  }
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
      "--include-drafts" if !include_drafts &&
        command != "recover" &&
        command != "init" &&
        command != "posts" &&
        command != "new" &&
        command != "read" &&
        command != "save" => include_drafts = true
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
    if command == "read" {
      let report = @lib.read_post(args[2], args[3])
      if json {
        print_report(command, false, report.to_json())
      } else {
        println("Version: " + report.digest)
        println(report.content)
      }
    } else if command == "save" {
      let report = @lib.save_post_from_file(args[2], args[3], args[4], args[5])
      if json {
        print_report(command, false, report.to_json())
      } else {
        println(
          "Saved: " +
          report.source.to_json().stringify() +
          " (changed: \{report.changed})",
        )
        println("Version: " + report.digest)
      }
    } else if command == "new" {
      let report = @lib.new_post(args[2], args[3], args[4])
      if json {
        print_report(command, false, report.to_json())
      } else {
        println("Created draft: " + report.source.to_json().stringify())
        println(
          "Edit the source, then preview with build --include-drafts in a separate output directory.",
        )
      }
    } else if command == "posts" {
      let report = @lib.list_posts(args[2])
      if json {
        print_report(command, false, report.to_json())
      } else {
        for post in report.posts {
          let state = if post.draft { "draft" } else { "ready" }
          println(
            state +
            "\t" +
            post.source.to_json().stringify() +
            "\t" +
            post.title.to_json().stringify() +
            "\t" +
            post.output.to_json().stringify(),
          )
        }
        println(
          "Posts: \{report.posts.length()} (ready means included in normal builds, not deployed)",
        )
      }
    } else if command == "init" {
      let report = @lib.init_site(args[2])
      if json {
        print_report(command, false, report.to_json())
      } else {
        println(
          "Created site: " +
          report.directory +
          " (\{report.files.length()} files)",
        )
        println(
          "See the generated README.md for editing, check and build commands.",
        )
      }
    } else if command == "recover" {
      let report = @lib.recover_output(args[2])
      if json {
        print_report(command, false, report.to_json())
      } else {
        println(
          "Recovery: \{report.action}, restored: \{report.restored}, removed: \{report.removed}",
        )
      }
    } else if command == "check" {
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
