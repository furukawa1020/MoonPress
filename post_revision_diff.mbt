///|
pub(all) struct RevisionLine {
  action : String
  text : String
} derive(ToJson)

///|
pub extend RevisionLine with ToJson::{to_json}

///|
pub(all) struct RevisionComparison {
  name : String
  current_digest : String
  revision_digest : String
  lines : Array[RevisionLine]
} derive(ToJson)

///|
pub extend RevisionComparison with ToJson::{to_json}

///|
fn revision_line_diff(
  before : String,
  after : String,
) -> Array[RevisionLine] raise {
  if @utf8.encode(before).length() > 262144 ||
    @utf8.encode(after).length() > 262144 {
    raise InvalidInput("Revision comparison is limited to 256 KiB per version")
  }
  let old = before.split("\n").map(p => p.to_owned()).to_array()
  let next = after.split("\n").map(p => p.to_owned()).to_array()
  if old.length() > 2000 || next.length() > 2000 {
    raise InvalidInput(
      "Revision comparison is limited to 2000 lines per version",
    )
  }
  let mut prefix = 0
  while prefix < old.length() &&
        prefix < next.length() &&
        old[prefix] == next[prefix] {
    prefix += 1
  }
  let mut suffix = 0
  while suffix < old.length() - prefix &&
        suffix < next.length() - prefix &&
        old[old.length() - 1 - suffix] == next[next.length() - 1 - suffix] {
    suffix += 1
  }
  let lines : Array[RevisionLine] = []
  for i in 0..<prefix {
    lines.push({ action: "keep", text: old[i], })
  }
  for i = prefix; i < old.length() - suffix; i = i + 1 {
    lines.push({ action: "remove", text: old[i], })
  }
  for i = prefix; i < next.length() - suffix; i = i + 1 {
    lines.push({ action: "add", text: next[i], })
  }
  for i = next.length() - suffix; i < next.length(); i = i + 1 {
    lines.push({ action: "keep", text: next[i], })
  }
  lines
}

///|
pub fn compare_post_revision(
  input : String,
  name : String,
  id : String,
) -> RevisionComparison raise {
  let revision = read_post_revision(input, id)
  if revision.revision.name != name {
    raise InvalidInput("Revision belongs to another article")
  }
  let current = read_post(input, name)
  {
    name,
    current_digest: current.digest,
    revision_digest: revision.revision.digest,
    lines: revision_line_diff(revision.content, current.content),
  }
}

///|
fn admin_revision_diff(
  input : String,
  fields : Map[String, String],
) -> String raise {
  if fields.length() != 2 {
    raise InvalidInput("Revision comparison requires exactly name and id")
  }
  let name = admin_field(fields, "name")
  let id = admin_field(fields, "id")
  let report = compare_post_revision(input, name, id)
  let out = StringBuilder()
  out.write_string(
    "<p>" +
    admin_i18n(
      "過去の版から現在の内容への差分です。共通の先頭・末尾を残し、間の変更箇所をまとめて表示します。最小差分ではありません。",
      "Changes from the revision to current content. Common leading and trailing lines are retained; the changed middle is shown as a replacement, not a minimal diff.",
    ) +
    "</p><p>Current SHA-256: <code>" +
    report.current_digest +
    "</code></p>" +
    admin_table_start("Revision comparison") +
    "<thead><tr><th>Action</th><th>Source line</th></tr></thead><tbody>",
  )
  for line in report.lines {
    out.write_string(
      "<tr><td>" +
      line.action +
      "</td><td><pre>" +
      escape_html(line.text) +
      "</pre></td></tr>",
    )
  }
  out.write_string(
    "</tbody></table></div><p><a href=\"/revision?name=" +
    url_component(name) +
    "&amp;id=" +
    id +
    "\">" +
    admin_i18n("版の確認と復元へ", "Inspect or restore this revision") +
    "</a></p>",
  )
  admin_page("Revision comparison", out.to_string())
}
