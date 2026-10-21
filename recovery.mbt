///|
pub(all) struct RecoveryReport {
  action : String
  restored : Int
  removed : Int
} derive(ToJson)

///|
fn require_recovery_digest(
  path : String,
  expected : String,
  max_bytes? : Int = 2147483647,
) -> Unit raise {
  if path_kind(path) != 1 ||
    digest_bytes(read_opened_file(open_file(path, 0), path, max_bytes~)) !=
    expected {
    raise InvalidInput("Recovery found changed or non-regular file: " + path)
  }
}

///|
pub fn recover_output(output : String) -> RecoveryReport raise {
  recovery_operation(output, apply=true)
}

///|
// Read-only snapshot; recover_output always revalidates current state.
pub fn inspect_recovery(output : String) -> RecoveryReport raise {
  recovery_operation(output, apply=false)
}

///|
fn recovery_operation(output : String, apply~ : Bool) -> RecoveryReport raise {
  let output = output.trim_end(chars="/").to_owned()
  if output.is_empty() {
    raise InvalidInput("Root output directory is not allowed")
  }
  let lock = lock_output(output, shared=!apply)
  defer native_unlock_output(lock)
  let record = recovery_record_path(output)
  let record_kind = path_kind(record)
  if record_kind != 0 && record_kind != 1 {
    raise InvalidInput("Recovery record must be a regular file")
  }
  let output_kind = path_kind(output)
  if output_kind == 0 && record_kind == 0 {
    return { action: "absent", restored: 0, removed: 0, }
  }
  if output_kind != 0 && output_kind != 2 {
    raise InvalidInput("Recovery output must be a real directory")
  }
  let stage = output + "/.moonpress-stage"
  let stage_kind = path_kind(stage)
  if stage_kind == 0 && record_kind == 0 {
    load_previous(output) |> ignore
    return { action: "clean", restored: 0, removed: 0, }
  }
  if stage_kind != 0 && stage_kind != 2 {
    raise InvalidInput("Recovery staging must be a real directory")
  }
  let journal_path = if record_kind == 1 { record } else { stage + "/journal" }
  if path_kind(journal_path) != 1 {
    raise InvalidInput(
      "Recovery requires a complete regular publication journal",
    )
  }
  let journal_text = read_publication_text(journal_path, 64 * 1024 * 1024)
  let journal = parse_journal(journal_text)
  if output_kind == 0 {
    if journal.previous is Some(_) {
      raise InvalidInput("Recovery output unexpectedly missing")
    }
    if apply {
      remove_recovery_record(output)
    }
    return { action: "rolled_back", restored: 0, removed: 0, }
  }
  let previous = match journal.previous {
    None => Map([])
    Some(text) => artifact_map(parse_manifest(text).artifacts)
  }
  let next = artifact_map(parse_manifest(journal.next).artifacts)
  let present = journal_names(journal.present)
  let writes = journal_names(journal.writes)
  let affected = journal.writes.copy()
  for name, _ in previous {
    if !next.contains(name) {
      affected.push(name)
    }
  }
  affected.sort()
  let expected_backups : Map[String, String] = Map([])
  for name in affected {
    if present.contains(name) {
      expected_backups[name] = previous[name].digest
    }
  }
  let backup = stage + "/backup"
  let backups : Map[String, Bool] = Map([])
  let backup_kind = path_kind(backup)
  if backup_kind != 0 && backup_kind != 2 {
    raise InvalidInput("Recovery backup must be a real directory")
  }
  if backup_kind == 2 {
    for name in @fs.read_dir(backup) {
      match expected_backups.get(name) {
        None => raise InvalidInput("Unknown recovery backup: " + name)
        Some(digest) => require_recovery_digest(backup + "/" + name, digest)
      }
      backups[name] = true
    }
  }
  // Validate every staging entry, including payloads no longer needed by rollback.
  let stage_entries = if stage_kind == 2 { @fs.read_dir(stage) } else { [] }
  for name in stage_entries {
    if name == "backup" {
      continue
    }
    let digest = if name == "journal" {
      digest_text(journal_text)
    } else if name == ".moonpress.json" &&
      journal.previous != Some(journal.next) {
      digest_text(journal.next)
    } else if writes.contains(name) {
      next[name].digest
    } else {
      raise InvalidInput("Unknown recovery staging entry: " + name)
    }
    let max_bytes = if name == "journal" {
      64 * 1024 * 1024
    } else if name == ".moonpress.json" {
      4 * 1024 * 1024
    } else {
      2147483647
    }
    require_recovery_digest(stage + "/" + name, digest, max_bytes~)
  }
  let marker = output + "/.moonpress.json"
  let current_manifest = match path_kind(marker) {
    0 => None
    1 => Some(read_publication_text(marker, 4 * 1024 * 1024))
    _ => raise InvalidInput("Recovery manifest must be a regular file")
  }
  if current_manifest != journal.previous &&
    current_manifest != Some(journal.next) {
    raise InvalidInput("Recovery manifest does not match the journal")
  }
  let current : Map[String, String] = Map([])
  for name in @fs.read_dir(output) {
    if name == ".moonpress.json" || name == ".moonpress-stage" {
      continue
    }
    let path = output + "/" + name
    if path_kind(path) != 1 {
      raise InvalidInput("Recovery found non-regular output: " + name)
    }
    let digest = digest_bytes(read_bytes(path))
    let old_matches = present.contains(name) &&
      previous.get(name).map(artifact => artifact.digest) == Some(digest)
    let new_matches = writes.contains(name) &&
      next.get(name).map(artifact => artifact.digest) == Some(digest)
    if !old_matches && !new_matches {
      raise InvalidInput("Recovery found edited or unknown output: " + name)
    }
    current[name] = digest
  }
  for name in journal.present {
    if next.contains(name) && !current.contains(name) {
      raise InvalidInput("Recovery found unexpected missing output: " + name)
    }
  }
  let complete = current.length() == next.length() &&
    next.iter().all(entry => current.get(entry.0) == Some(entry.1.digest))
  let committed = current_manifest == Some(journal.next) && complete
  if !committed && current_manifest != journal.previous {
    raise InvalidInput(
      "Committed recovery output does not match the next manifest",
    )
  }
  if !committed {
    for name, digest in expected_backups {
      if !backups.contains(name) && current.get(name) != Some(digest) {
        raise InvalidInput("Recovery is missing required backup: " + name)
      }
    }
  }
  // No filesystem mutation above this line. Cleanup removes the journal last.
  let mut record_retained = record_kind == 1
  if apply && !record_retained && !committed && journal.previous is None {
    // Removing a fresh output needs parent write access; retain intent first.
    write_atomic_new(record, @utf8.encode(journal_text))
    record_retained = true
  }
  let mut restored = 0
  let mut removed = 0
  if !committed {
    for index = affected.length() - 1; index >= 0; index = index - 1 {
      let name = affected[index]
      if backups.contains(name) {
        if apply {
          replace_staged_file(backup + "/" + name, output + "/" + name)
        }
        restored += 1
      } else if !present.contains(name) && current.contains(name) {
        if apply {
          @fs.remove_file(output + "/" + name)
        }
        removed += 1
      }
    }
  }
  let staged = journal.writes.copy()
  staged.push(".moonpress.json")
  if apply {
    // Never discard backups until the selected public state is persistent.
    sync_publication_directory(output)
    if backup_kind == 2 {
      sync_publication_directory(backup)
    }
    cleanup_stage(stage, staged, affected, backup_kind == 2, true)
    if !committed && journal.previous is None {
      @fs.remove_dir(output)
      sync_publication_directory(output, parent=true)
    }
    if record_retained {
      remove_recovery_record(output)
    }
  }
  {
    action: if committed {
      "finalized"
    } else {
      "rolled_back"
    },
    restored,
    removed,
  }
}

///|
pub extend RecoveryReport with ToJson::{to_json}
