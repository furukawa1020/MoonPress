///|
#borrow(source, target)
extern "C" fn native_replace_file(source : Bytes, target : Bytes) -> Int = "moonpress_replace_file"

///|
fn replace_staged_file(source : String, target : String) -> Unit raise {
  let result = native_replace_file(
    @utf8.encode(source) + b"\x00",
    @utf8.encode(target) + b"\x00",
  )
  if result != 0 {
    raise InvalidInput(
      "Cannot replace staged file " + target + " (errno \{result})",
    )
  }
}

///|
#borrow(source, target)
extern "C" fn native_link_file(source : Bytes, target : Bytes) -> Int = "moonpress_link_file"

///|
fn backup_file(
  output : String,
  backup : String,
  name : String,
  backed : Array[String],
) -> Unit raise {
  let source = output + "/" + name
  if path_kind(source) == 0 {
    return
  }
  if path_kind(source) != 1 {
    raise InvalidInput("Cannot back up non-regular output: " + source)
  }
  let result = native_link_file(
    @utf8.encode(source) + b"\x00",
    @utf8.encode(backup + "/" + name) + b"\x00",
  )
  if result != 0 {
    raise InvalidInput(
      "Cannot preserve output before publication: " +
      source +
      " (errno \{result})",
    )
  }
  backed.push(name)
}

///|
fn rollback_publication(
  output : String,
  backup : String,
  applied : Array[String],
  backed : Array[String],
) -> Unit raise {
  let preserved : Map[String, Bool] = Map([])
  for name in backed {
    preserved[name] = true
  }
  for index = applied.length() - 1; index >= 0; index = index - 1 {
    let name = applied[index]
    if preserved.contains(name) {
      replace_staged_file(backup + "/" + name, output + "/" + name)
    } else {
      // Only successful writes from this invocation can appear without a backup.
      let path = output + "/" + name
      match path_kind(path) {
        0 => ()
        1 => @fs.remove_file(path)
        _ => raise InvalidInput("Cannot roll back non-regular output: " + path)
      }
    }
  }
}

///|
fn apply_plan(output : String, plan : BuildPlan) -> Unit raise {
  let fresh = path_kind(output) == 0
  let marker = output + "/.moonpress.json"
  let previous = if fresh {
    None
  } else {
    Some(read_publication_text(marker, 4 * 1024 * 1024))
  }
  require_publication_manifest_size(plan.manifest)
  let manifest_changed = previous != Some(plan.manifest)
  if plan.report.written == 0 && plan.removed.is_empty() && !manifest_changed {
    return
  }
  let present = if fresh {
    []
  } else {
    @fs.read_dir(output).filter(name => name != ".moonpress.json")
  }
  present.sort()
  let stage = output + "/.moonpress-stage"
  let staged : Array[String] = []
  let backup = stage + "/backup"
  let backed : Array[String] = []
  let applied : Array[String] = []
  let mut backup_created = false
  let mut journal_created = false
  let mut record_retained = false
  let mut output_created = false
  let mut stage_created = false
  let mut publishing = false
  let mut committed = false
  let mut commit_synced = false
  try {
    let writes = plan.pending.filter_map(item => {
      if item.content is Some(_) {
        Some(item.artifact.name)
      } else {
        None
      }
    })
    let journal : PublicationJournal = {
      schema: 1,
      previous,
      next: plan.manifest,
      present,
      writes,
    }
    let text = ToJson::to_json(journal).stringify() + "\n"
    parse_journal(text) |> ignore

    write_atomic_new(recovery_record_path(output), @utf8.encode(text))
    record_retained = true
    if fresh {
      @fs.create_dir(output)
      output_created = true
    }
    @fs.create_dir(stage)
    stage_created = true
    write_atomic_new(stage + "/journal", @utf8.encode(text))
    journal_created = true
    for item in plan.pending {
      if item.content is Some(bytes) {
        staged.push(item.artifact.name)
        write_atomic_new(stage + "/" + item.artifact.name, bytes)
      }
    }
    if manifest_changed {
      staged.push(".moonpress.json")
      write_atomic_new(stage + "/.moonpress.json", @utf8.encode(plan.manifest))
    }
    @fs.create_dir(backup)
    backup_created = true
    for item in plan.pending {
      if item.content is Some(_) {
        backup_file(output, backup, item.artifact.name, backed)
      }
    }
    for name in plan.removed {
      backup_file(output, backup, name, backed)
    }
    // Establish recovery prerequisites before the first public-file mutation.
    for name in backed {
      sync_publication_file(backup + "/" + name)
    }
    if previous is Some(_) {
      sync_publication_file(marker)
    }
    sync_publication_directory(backup)
    sync_publication_directory(stage)
    sync_publication_directory(output)
    sync_publication_directory(recovery_record_path(output), parent=true)
    publishing = true
    for item in plan.pending {
      if item.content is Some(_) {
        replace_staged_file(
          stage + "/" + item.artifact.name,
          output + "/" + item.artifact.name,
        )
        applied.push(item.artifact.name)
      }
    }
    for name in plan.removed {
      if path_kind(output + "/" + name) == 1 {
        @fs.remove_file(output + "/" + name)
        applied.push(name)
      }
    }
    // Persist artifact names before the manifest can identify the new tree.
    sync_publication_directory(output)
    sync_publication_directory(stage)
    if manifest_changed {
      replace_staged_file(stage + "/.moonpress.json", marker)
    }
    committed = true
    // A failed barrier after rename must retain the journal, never roll back.
    sync_publication_directory(output)
    sync_publication_directory(stage)
    commit_synced = true
    cleanup_stage(stage, staged, backed, backup_created, journal_created)
    remove_recovery_record(output)
  } catch {
    error => {
      let rollback_error = if publishing && !committed {
        try {
          rollback_publication(output, backup, applied, backed)
          sync_publication_directory(output)
          sync_publication_directory(backup)
          None
        } catch {
          cause => Some("\{cause}")
        }
      } else {
        None
      }
      // Failed rollback keeps remaining backups for inspection; never discard them.
      let cleaned = if rollback_error is Some(_) ||
        (committed && !commit_synced) {
        false
      } else {
        try {
          if publishing && !record_retained {
            retain_recovery_record(output, stage)
            record_retained = true
          }
          if stage_created {
            cleanup_stage(
              stage, staged, backed, backup_created, journal_created,
            )
          }
          if output_created && !committed {
            @fs.remove_dir(output)
            sync_publication_directory(output, parent=true)
          }
          if record_retained {
            remove_recovery_record(output)
          }
          true
        } catch {
          _ => false
        }
      }
      let phase = if committed {
        "Publication committed; staging cleanup failed"
      } else if rollback_error is Some(cause) {
        "Publication failed; rollback incomplete (" +
        cause +
        "); backups retained; try moonpress recover or use a fresh output directory"
      } else if publishing {
        "Publication failed; previous output restored"
      } else {
        "Staging failed before existing artifacts were changed"
      }
      let cleanup = if cleaned { "" } else { "; staging cleanup incomplete" }
      raise InvalidInput(phase + " for " + output + ": \{error}" + cleanup)
    }
  }
}

///|
fn cleanup_stage(
  stage : String,
  names : Array[String],
  backed : Array[String],
  backup_created : Bool,
  journal_created : Bool,
) -> Unit raise {
  if path_kind(stage) == 0 {
    return
  }
  for name in names {
    let path = stage + "/" + name
    if path_kind(path) == 1 {
      @fs.remove_file(path)
    }
  }
  if backup_created && path_kind(stage + "/backup") != 0 {
    let backup = stage + "/backup"
    for name in backed {
      let path = backup + "/" + name
      if path_kind(path) == 1 {
        @fs.remove_file(path)
      }
    }
    sync_publication_directory(backup)
    @fs.remove_dir(backup)
    sync_publication_directory(stage)
  }
  if journal_created && path_kind(stage + "/journal") == 1 {
    @fs.remove_file(stage + "/journal")
  }
  sync_publication_directory(stage)
  // Never recursively delete unknown entries.
  @fs.remove_dir(stage)
  sync_publication_directory(stage, parent=true)
}
