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
  value == "references" ||
  value == "backlinks" ||
  value == "review" ||
  value == "build-reviewed" ||
  value == "routes" ||
  value == "plan" ||
  value == "diff" ||
  value == "impact" ||
  value == "deps" ||
  value == "audit" ||
  value == "import" ||
  value == "media-refs" ||
  value == "media" ||
  value == "admin" ||
  value == "status" ||
  value == "read" ||
  value == "save" ||
  value == "duplicate" ||
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
    "references" =>
      "Usage: moonpress references <site-directory> [--include-drafts] [--json]"
    "backlinks" =>
      "Usage: moonpress backlinks <site-directory> <output-name> [--include-drafts] [--json]"
    "review" =>
      "Usage: moonpress review <site-directory> <output-directory> [--include-drafts] [--json]"
    "build-reviewed" =>
      "Usage: moonpress build-reviewed <site-directory> <output-directory> <review-id> [--include-drafts] [--json]"
    "routes" =>
      "Usage: moonpress routes <site-directory> [--include-drafts] [--json]"
    "plan" =>
      "Usage: moonpress plan <site-directory> <output-directory> [--include-drafts] [--json]"
    "diff" =>
      "Usage: moonpress diff <old-manifest-file> <new-manifest-file> [--json]"
    "deps" =>
      "Usage: moonpress deps <site-directory> [--include-drafts] [--json]"
    "audit" => "Usage: moonpress audit <output-directory> [--json]"
    "import" =>
      "Usage: moonpress import <site-directory> <source-file> <destination-name> [--json]"
    "media-refs" => "Usage: moonpress media-refs <site-directory> [--json]"
    "media" => "Usage: moonpress media <site-directory> [--json]"
    "admin" => "Usage: moonpress admin <site-directory> <port>"
    "status" =>
      "Usage: moonpress status <site-directory> <filename.md> <expected-digest> <draft|ready> [--json]"
    "read" => "Usage: moonpress read <site-directory> <filename.md> [--json]"
    "save" =>
      "Usage: moonpress save <site-directory> <filename.md> <expected-digest> <replacement-file> [--json]"
    "duplicate" =>
      "Usage: moonpress duplicate <site-directory> <filename.md> <expected-digest> <new-stem> <new-title> [--json]"
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
      "Usage: moonpress <build|explain> <site-directory> <output-directory> [--include-drafts] [--json]\n       moonpress check <site-directory> [--include-drafts] [--json]\n       moonpress init <site-directory> [--json]\n       moonpress recover <output-directory> [--json]\n       moonpress [--help|-h|--version]\n       moonpress <references|backlinks|review|build-reviewed|routes|plan|diff|impact|deps|audit|admin|media-refs|media|import|init|duplicate|new|posts|read|save|status|build|check|explain|recover> [--help|-h]"
  }
}

///|
fn help_text(command : String) -> String {
  let description = match command {
    "references" =>
      "Inspect authored local references with source and consuming output evidence.\nSame compiler validation as build; no files written. Excludes external URLs, CSS and generated navigation."
    "backlinks" =>
      "Inspect incoming and outgoing authored references for an exact output filename.\nUse decoded names such as 月.html, not source paths or encoded URLs.\nUnknown routes are errors; zero incoming edges never proves deletion safety."
    "review" =>
      "Inspect a read-only build plan and its versioned SHA-256 review ID.\nThe ID binds exact path spellings, draft mode, output actions and dependencies.\nIt is not authentication, a reservation or evidence of deployment."
    "build-reviewed" =>
      "Recompute the plan under the output lock and build only if its review ID matches.\nA changed plan fails before publication; inspect with review again.\nUse the same path spellings and draft mode as the review. No hosting deployment."
    "routes" =>
      "Inspect every planned route with kind, source and terminal redirect target.\nCompile and validate sources in memory; no files written and no output directory needed."
    "plan" =>
      "Inspect the actual incremental plan with complete dependency changes.\nDry run: no files or directories are written; output ownership checks still apply."
    "diff" =>
      "Compare two validated ownership manifests; write no files.\nDifferences are successful reports (exit 0); source/output bytes are not inspected."
    "audit" => "Inspect compiler-owned output without sources; write no files."
    "import" =>
      "Copy a regular local file into an existing public directory without overwriting.\nThe destination must be a supported flat asset filename. No deployment performed."
    "media-refs" =>
      "Inspect supported article Markdown references, including drafts; no files written.\nDiagnostics make incomplete scans explicit. Empty lists do not prove deletion safety."
    "media" =>
      "List public assets with byte counts, digests and article URLs; no files written."
    "admin" =>
      "Start the local browser editor on http://127.0.0.1:<port>/.\nPort must be 1024–65535. Ctrl-C stops the server. No deployment or --json option.\nUse only on a trusted local machine; do not expose through a proxy or tunnel."
    "status" =>
      "Set draft or ready-for-build status with source version checks.\nReady includes the article in normal builds; it does not deploy the site."
    "read" =>
      "Read a post source and SHA-256 version for editing; no files written."
    "save" =>
      "Save validated replacement source only if the expected version matches.\nExisting source stays intact on caught preparation failures; no hosting action."
    "duplicate" =>
      "Copy a saved valid article into a new draft with a source version check.\nRetain body/tags/layout/listing; clear old slug/date. Never overwrite or deploy."
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
      "MoonPress: a native MoonBit static-site compiler.\n\nCommands:\n  references  Inspect authored local reference edges.\n  backlinks   Inspect references to/from an output filename.\n  review   Inspect a build plan and its review ID.\n  build-reviewed  Build only the reviewed plan.\n  routes   Inspect compiled output routes and their sources.\n  plan     Inspect detailed protected incremental changes.\n  diff     Compare saved ownership manifest snapshots.\n  impact   Query direct output impact of a dependency key.\n  deps     Inspect compiled output dependency edges.\n  audit    Inspect compiler-owned output integrity.\n  duplicate  Copy an article into a new draft.\n  media-refs  Inspect article references to public assets.\n  import   Import a local public asset without overwriting.\n  media    List public assets and article URLs.\n  admin    Start the local browser post editor.\n  status   Change draft/ready-for-build status with version checks.\n  read     Read post source and version.\n  save     Save post source with stale-version protection.\n  new      Create a draft article without overwriting existing files.\n  posts    List posts and draft status without building.\n  init     Create a starter site in a new directory.\n  build    Compile and update a new or MoonPress-managed output directory.\n  check    Validate sources in memory without writing generated files.\n  explain  Report planned changes without writing files or directories.\n  recover  Recover a journaled interrupted publication without source input."
  }
  if command == "references" ||
    command == "backlinks" ||
    command == "routes" ||
    command == "deps" ||
    command == "impact" {
    return description +
      "\n\n" +
      usage(command) +
      "\n\n--include-drafts includes private draft nodes in the report, not deployed output.\n--json prints one schema-1 inspection report. Flags may appear once in either order.\nExit status: 0 report, 1 validation/I/O failure, 2 incorrect arguments.\nErrors use stderr with empty stdout."
  }
  if command == "audit" {
    return description +
      "\n\n" +
      usage(command) +
      "\n\n--json prints a schema-1 report. No --include-drafts option.\nExit status: 0 healthy, 1 findings or validation/I/O failure, 2 incorrect arguments.\nFindings exit 1 with the complete report on stdout; operation errors use stderr with empty stdout."
  }
  if command == "admin" {
    return description + "\n\n" + usage(command)
  }
  if command == "diff" ||
    command == "recover" ||
    command == "init" ||
    command == "import" ||
    command == "media-refs" ||
    command == "media" ||
    command == "posts" ||
    command == "duplicate" ||
    command == "new" ||
    command == "read" ||
    command == "save" ||
    command == "status" {
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
fn print_reference(direction : String, edge : @lib.ReferenceEdge) -> Unit {
  println(
    direction +
    "\t" +
    edge.source.to_json().stringify() +
    "\t" +
    edge.output.to_json().stringify() +
    "\t" +
    edge.kind +
    "\t" +
    edge.url.to_json().stringify() +
    "\t-> " +
    edge.target.to_json().stringify() +
    "\t" +
    edge.fragment.to_json().stringify(),
  )
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
  let required = if command == "duplicate" {
    7
  } else if command == "save" || command == "status" {
    6
  } else if command == "new" ||
    command == "import" ||
    command == "build-reviewed" {
    5
  } else if command == "references" ||
    command == "routes" ||
    command == "deps" ||
    command == "audit" ||
    command == "check" ||
    command == "recover" ||
    command == "init" ||
    command == "media-refs" ||
    command == "media" ||
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
      if (
          args[index].has_prefix("--") &&
          !(command == "backlinks" && index == 3)
        ) ||
        is_help(args[index]) {
        valid = false
      }
    }
  }
  let mut include_drafts = false
  let mut json = false
  for index = required; index < args.length(); index = index + 1 {
    match args[index] {
      "--include-drafts" if !include_drafts &&
        command != "diff" &&
        command != "audit" &&
        command != "recover" &&
        command != "init" &&
        command != "import" &&
        command != "media-refs" &&
        command != "media" &&
        command != "posts" &&
        command != "duplicate" &&
        command != "new" &&
        command != "read" &&
        command != "save" &&
        command != "status" &&
        command != "admin" => include_drafts = true
      "--json" if !json && command != "admin" => json = true
      _ => valid = false
    }
  }
  if command == "status" &&
    args.length() >= 6 &&
    args[5] != "draft" &&
    args[5] != "ready" {
    valid = false
  }
  let mut port = 0
  if command == "admin" && args.length() >= 4 {
    if args[3].is_empty() ||
      args[3].length() > 5 ||
      !args[3].all(c => c.is_ascii_digit()) {
      valid = false
    } else {
      for c in args[3] {
        port = port * 10 + c.to_int() - 48
      }
      if port < 1024 || port > 65535 {
        valid = false
      }
    }
  }
  if !valid {
    eprintln(usage(command))
    @sys.exit(2)
    return
  }
  try {
    if command == "references" {
      let report = @lib.inspect_references(args[2], include_drafts~)
      if json {
        print_report(command, include_drafts, report.to_json())
      } else {
        println(report.scope)
        for edge in report.references {
          print_reference("REF", edge)
        }
        println(
          "References: \{report.references.length()} authored local edges, \{report.routes.length()} routes; no files written",
        )
      }
    } else if command == "backlinks" {
      let report = @lib.inspect_backlinks(args[2], args[3], include_drafts~)
      if json {
        print_report(command, include_drafts, report.to_json())
      } else {
        println(report.scope)
        println("Output: " + report.route.name.to_json().stringify())
        for edge in report.incoming {
          print_reference("IN", edge)
        }
        for edge in report.outgoing {
          print_reference("OUT", edge)
        }
        println(
          "References: \{report.incoming.length()} incoming, \{report.outgoing.length()} outgoing; no files written",
        )
      }
    } else if command == "review" {
      let report = @lib.review_build_plan(args[2], args[3], include_drafts~)
      if json {
        print_report(command, include_drafts, report.to_json())
      } else {
        println("Review ID: " + report.review_id)
        // Print the complete plan, including all digests and dependency deltas.
        println(report.to_json().stringify())
        println(
          "No files written. Use build-reviewed with this ID and the same paths and draft mode.",
        )
      }
    } else if command == "build-reviewed" {
      let report = @lib.compile_reviewed_site(
        args[2],
        args[3],
        args[4],
        include_drafts~,
      )
      if json {
        print_report(command, include_drafts, report.to_json())
      } else {
        for event in report.events {
          println(event)
        }
        println(
          "Reviewed build: \{report.pages} pages, \{report.written} writes, \{report.skipped} kept, \{report.deleted} deletions; no deployment performed",
        )
      }
    } else if command == "routes" {
      let report = @lib.inspect_routes(args[2], include_drafts~)
      if json {
        print_report(command, include_drafts, report.to_json())
      } else {
        for route in report.routes {
          println(
            route.kind +
            "\t" +
            route.name.to_json().stringify() +
            "\t" +
            route.source.to_json().stringify() +
            "\t" +
            route.target.to_json().stringify(),
          )
        }
        println(
          "Routes: \{report.pages} pages, \{report.routes.length()} outputs; no files written",
        )
      }
    } else if command == "plan" {
      let report = @lib.inspect_build_plan(args[2], args[3], include_drafts~)
      if json {
        print_report(command, include_drafts, report.to_json())
      } else {
        for output in report.outputs {
          println(
            output.action.to_upper() +
            " " +
            output.name.to_json().stringify() +
            " — " +
            output.reason,
          )
          for dep in output.dependencies {
            println(
              "  " +
              dep.action +
              "\t" +
              dep.name.to_json().stringify() +
              "\t" +
              dep.old_digest.to_json().stringify() +
              " -> " +
              dep.new_digest.to_json().stringify(),
            )
          }
        }
        println(
          "Detailed plan: \{report.summary.pages} pages, \{report.summary.written} writes, \{report.summary.skipped} kept, \{report.summary.deleted} deletions; no files written",
        )
      }
    } else if command == "diff" {
      let report = @lib.compare_manifest_files(args[2], args[3])
      if json {
        print_report(command, false, report.to_json())
      } else {
        for output in report.outputs {
          println(
            output.action +
            "\t" +
            output.name.to_json().stringify() +
            "\tcontent_changed=" +
            output.content_changed.to_string(),
          )
          for dep in output.dependencies {
            println(
              "  " +
              dep.action +
              "\t" +
              dep.name.to_json().stringify() +
              "\t" +
              dep.old_digest.to_json().stringify() +
              " -> " +
              dep.new_digest.to_json().stringify(),
            )
          }
        }
        println(
          "Manifest difference: \{report.added} added, \{report.removed} removed, \{report.changed} changed, \{report.unchanged} unchanged; no files written",
        )
      }
    } else if command == "impact" {
      let report = @lib.inspect_impact(args[2], [args[3]], include_drafts~)
      if json {
        print_report(command, include_drafts, report.to_json())
      } else {
        for output in report.outputs {
          println(
            output.name.to_json().stringify() +
            "\t" +
            output.digest +
            "\t" +
            output.dependencies.to_json().stringify(),
          )
        }
        for name in report.unknown {
          println("UNKNOWN " + name.to_json().stringify())
        }
        println(
          "Direct impact: \{report.outputs.length()} outputs, \{report.unknown.length()} unknown keys; no files written",
        )
        println(
          "Exact current graph keys only. Use explain after saving edits for the actual rebuild plan.",
        )
      }
    } else if command == "deps" {
      let report = @lib.inspect_dependencies(args[2], include_drafts~)
      if json {
        print_report(command, include_drafts, report.to_json())
      } else {
        let mut edges = 0
        for artifact in report.artifacts {
          println(artifact.name.to_json().stringify() + "\t" + artifact.digest)
          for dep in artifact.dependencies {
            println(
              "  <- " + dep.name.to_json().stringify() + "\t" + dep.digest,
            )
            edges += 1
          }
        }
        println(
          "Dependency graph: \{report.pages} pages, \{report.artifacts.length()} outputs, \{edges} direct edges; no files written",
        )
      }
    } else if command == "audit" {
      let report = @lib.audit_output(args[2])
      if json {
        print_report(command, false, report.to_json())
      } else {
        for finding in report.findings {
          println(
            finding.status +
            "\t" +
            finding.path.to_json().stringify() +
            "\t" +
            finding.message.to_json().stringify(),
          )
        }
        println(
          "Healthy: \{report.healthy}; findings: \{report.findings.length()}",
        )
      }
      if !report.healthy {
        @sys.exit(1)
      }
    } else if command == "admin" {
      @lib.serve_admin(args[2], port)
    } else if command == "status" {
      let report = @lib.set_post_draft(
        args[2],
        args[3],
        args[4],
        args[5] == "draft",
      )
      if json {
        print_report(command, false, report.to_json())
      } else {
        println(
          "Status: " +
          args[5] +
          " (changed: \{report.changed}); no deployment performed",
        )
        println("Version: " + report.digest)
      }
    } else if command == "read" {
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
    } else if command == "duplicate" {
      let report = @lib.duplicate_post(
        args[2],
        args[3],
        args[4],
        args[5],
        args[6],
      )
      if json {
        print_report(command, false, report.to_json())
      } else {
        println("Duplicated draft: " + report.source.to_json().stringify())
        println(
          "Original source unchanged. Validate and preview the copy before marking it ready; no deployment performed.",
        )
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
    } else if command == "import" {
      let report = @lib.import_media(args[2], args[3], args[4])
      if json {
        print_report(command, false, report.to_json())
      } else {
        println(
          "Imported: " +
          report.source.to_json().stringify() +
          " (\{report.bytes} bytes); URL: " +
          report.url.to_json().stringify() +
          "; no deployment performed",
        )
      }
    } else if command == "media-refs" {
      let report = @lib.inspect_media_references(args[2])
      if json {
        print_report(command, false, report.to_json())
      } else {
        println(report.scope)
        for asset in report.assets {
          println(
            asset.item.source.to_json().stringify() +
            ": \{asset.posts.length()} referring articles",
          )
          for post in asset.posts {
            println(
              "  " +
              post.source.to_json().stringify() +
              " (" +
              (if post.draft { "draft" } else { "ready" }) +
              (if post.listed { "" } else { ", unlisted" }) +
              ")",
            )
          }
        }
        for problem in report.problems {
          println(
            "DIAGNOSTIC " +
            problem.source.to_json().stringify() +
            ": " +
            problem.message.to_json().stringify(),
          )
        }
        println("Scan diagnostics: \{report.problems.length()}")
      }
    } else if command == "media" {
      let report = @lib.list_media(args[2])
      if json {
        print_report(command, false, report.to_json())
      } else {
        for item in report.items {
          println(
            item.source.to_json().stringify() +
            "\t" +
            item.bytes.to_string() +
            "\t" +
            item.url.to_json().stringify() +
            "\t" +
            item.digest,
          )
        }
        println(
          "Media: \{report.items.length()} (extension classification only; no files written)",
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
