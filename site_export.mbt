///|
pub(all) struct SiteExportReport {
  review_id : String
  files : Array[String]
  bytes : Int
  digest : String
} derive(ToJson)

///|
pub extend SiteExportReport with ToJson::{to_json}

///|
pub(all) struct SiteExport {
  report : SiteExportReport
  content : Bytes
}

///|
fn export_read(
  directory : AuthoringDirectory,
  name : String,
  limit : Int,
) -> Bytes raise {
  let file = directory_read(directory.fd, @utf8.encode(name) + b"\x00")
  if io_is_null(file) != 0 {
    raise io_failure("export read", name)
  }
  read_opened_file(file, directory.path + "/" + name, max_bytes=limit)
}

///|
pub fn export_site(
  input : String,
  output : String,
  expected_review : String,
) -> SiteExport raise {
  require_review(expected_review, expected_review)
  let normalized = normalize_output(output)
  let lock = lock_output(normalized, shared=true)
  defer native_unlock_output(lock)
  let directory = open_authoring_directory(normalized)
  defer directory_close(directory.fd)
  let manifest_text = decode_text(
    export_read(directory, ".moonpress.json", 4194304),
    "export manifest",
  )
  let manifest = parse_manifest(manifest_text)
  if manifest.artifacts.length() > 10000 {
    raise InvalidInput("ZIP exceeds 10000 files")
  }
  let previous : Map[String, Artifact] = Map([])
  for artifact in manifest.artifacts {
    previous[artifact.name] = artifact
  }
  for name in @fs.read_dir(normalized) {
    if name != ".moonpress.json" && !previous.contains(name) {
      raise InvalidInput("Untracked export file: " + name)
    }
  }
  let entries : Array[ZipEntry] = []
  let mut budget = 22
  for artifact in manifest.artifacts {
    let name = artifact.name
    if name.has_prefix(".") && name != ".nojekyll" {
      raise InvalidInput("Internal export file: " + name)
    }
    budget = zip_entry_budget(budget, @utf8.encode(name).length(), 0)
    let content = export_read(directory, name, 67108864 - budget)
    budget = budget + content.length()
    if digest_bytes(content) != artifact.digest {
      raise InvalidInput("Edited export file: " + name)
    }
    entries.push({ name, content, })
  }
  let plan = plan_site(input, previous, Some(normalized))
  let state : OutputPlan = {
    previous,
    previous_manifest: Some(manifest_text),
    plan,
  }
  let review = review_plan(input, output, false, state)
  require_review(expected_review, review.review_id)
  if review.manifest_changed ||
    plan.report.written != 0 ||
    plan.report.deleted != 0 {
    raise InvalidInput(
      "Production output is not current; review and build before exporting",
    )
  }
  let content = encode_site_zip(entries)
  let files = entries.map(entry => entry.name)
  files.sort()
  {
    report: {
      review_id: review.review_id,
      files,
      bytes: content.length(),
      digest: digest_bytes(content),
    },
    content,
  }
}
