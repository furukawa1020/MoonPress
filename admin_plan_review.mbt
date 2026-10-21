///|
fn admin_output_effect(output : PlannedOutput) -> String {
  if output.action == "delete" {
    return "Remove generated output"
  }
  if output.action == "keep" {
    return "Keep existing output"
  }
  if output.old_digest is None {
    return "Create new output"
  }
  if output.reason == "output missing" {
    return "Restore missing output"
  }
  if output.old_digest == output.new_digest {
    return "Recompute; bytes unchanged"
  }
  "Replace changed output bytes"
}

///|
fn admin_digest(value : String?) -> String {
  match value {
    None => "<span>Absent</span>"
    Some(value) => "<code>" + escape_html(value) + "</code>"
  }
}

///|
fn admin_dependency_review(plan : DetailedBuildPlan) -> String {
  let out = StringBuilder()
  out.write_string(
    "<h2>Why these outputs change</h2><p>Every dependency delta comes from the same native compiler plan used by the CLI. Digests identify observed bytes; they are not signatures or deployment receipts.</p>",
  )
  let mut changed = 0
  for output in plan.outputs {
    if output.action == "keep" {
      continue
    }
    changed += 1
    out.write_string(
      "<section><h3><code>" +
      escape_html(output.name) +
      "</code></h3><p>" +
      admin_output_effect(output) +
      ". " +
      escape_html(output.reason) +
      "</p>",
    )
    if output.dependencies.is_empty() {
      out.write_string(
        "<p>No dependency changes. The compiler may still need to restore a missing owned file.</p>",
      )
    } else {
      out.write_string(
        admin_table_start("Dependency changes for " + output.name) +
        "<caption>Dependency changes for " +
        escape_html(output.name) +
        "</caption><thead><tr><th scope=\"col\">Dependency</th><th scope=\"col\">Change</th></tr></thead><tbody>",
      )
      for dependency in output.dependencies {
        out.write_string(
          "<tr><td><code>" +
          escape_html(dependency.name) +
          "</code></td><td>" +
          escape_html(dependency.action) +
          "</td></tr>",
        )
      }
      out.write_string("</tbody></table></div>")
    }
    out.write_string(
      "<details><summary>Inspect observed SHA-256 digests</summary><p>Output before: " +
      admin_digest(output.old_digest) +
      "</p><p>Output after: " +
      admin_digest(output.new_digest) +
      "</p>",
    )
    for dependency in output.dependencies {
      out.write_string(
        "<p><code>" +
        escape_html(dependency.name) +
        "</code> before: " +
        admin_digest(dependency.old_digest) +
        "; after: " +
        admin_digest(dependency.new_digest) +
        "</p>",
      )
    }
    out.write_string("</details></section>")
  }
  if changed == 0 {
    out.write_string("<p>No generated output needs writing or removal.</p>")
  }
  out.write_string("<h2>Drafts excluded from production</h2><ul>")
  let mut excluded = 0
  for event in plan.summary.changes {
    if event.action == "skip" {
      excluded += 1
      out.write_string(
        "<li><code>" +
        escape_html(event.path) +
        "</code>: " +
        escape_html(event.reason) +
        "</li>",
      )
    }
  }
  out.write_string("</ul>")
  if excluded == 0 {
    out.write_string("<p>No draft sources excluded.</p>")
  }
  out.to_string()
}
