///|
pub(all) struct OutputFinding {
  path : String
  status : String
  expected : String?
  actual : String?
  message : String
} derive(ToJson)

///|
pub extend OutputFinding with ToJson::{to_json}

///|
pub(all) struct OutputAudit {
  healthy : Bool
  findings : Array[OutputFinding]
} derive(ToJson)

///|
pub extend OutputAudit with ToJson::{to_json}

///|
fn output_digest_finding(artifact : Artifact, bytes : Bytes) -> OutputFinding {
  let actual = digest_bytes(bytes)
  let intact = actual == artifact.digest
  {
    path: artifact.name,
    status: if intact {
      "intact"
    } else {
      "edited"
    },
    expected: Some(artifact.digest),
    actual: Some(actual),
    message: if intact {
      "Artifact digest matches"
    } else {
      "Artifact differs from the ownership manifest"
    },
  }
}

///|
pub fn audit_output(output : String) -> OutputAudit raise {
  let output = output.trim_end(chars="/").to_owned()
  if output.is_empty() {
    raise InvalidInput("Output directory must not be empty or root")
  }
  let lock = lock_output(output, shared=true)
  defer native_unlock_output(lock)
  require_input_kind(output, 2)
  require_input_kind(output + "/.moonpress.json", 1)
  let manifest = parse_manifest(
    read_publication_text(output + "/.moonpress.json", 4 * 1024 * 1024),
  )
  let tracked : Map[String, Bool] = Map([])
  let findings : Array[OutputFinding] = []
  let record = recovery_record_path(output)
  if path_kind(record) != 0 {
    findings.push({
      path: record,
      status: "recovery",
      expected: None,
      actual: None,
      message: "Retained recovery record present; run recovery-plan before building. Contents not read",
    })
  }
  for artifact in manifest.artifacts {
    tracked[artifact.name] = true
    let file = output + "/" + artifact.name
    let kind = path_kind(file)
    if kind != 1 {
      findings.push({
        path: artifact.name,
        status: if kind == 0 {
          "missing"
        } else {
          "unsafe"
        },
        expected: Some(artifact.digest),
        actual: None,
        message: if kind == 0 {
          "Tracked artifact is missing"
        } else {
          "Tracked artifact is not a regular file; contents not read"
        },
      })
    } else {
      let finding = output_digest_finding(artifact, read_bytes(file)) catch {
        error =>
          {
            path: artifact.name,
            status: "unreadable",
            expected: Some(artifact.digest),
            actual: None,
            message: error.to_string(),
          }
      }
      findings.push(finding)
    }
  }
  for name in @fs.read_dir(output) {
    if name != ".moonpress.json" && !tracked.contains(name) {
      findings.push({
        path: name,
        status: if name == ".moonpress-stage" {
          "staging"
        } else {
          "foreign"
        },
        expected: None,
        actual: None,
        message: if name == ".moonpress-stage" {
          "Staging entry present; inspect recovery state. Contents not read"
        } else {
          "Entry is not owned by the manifest; contents not read"
        },
      })
    }
  }
  findings.sort_by((a, b) => a.path.compare(b.path))
  { healthy: findings.all(finding => finding.status == "intact"), findings, }
}
