///|
pub fn trash_post(
  input : String,
  name : String,
  expected : String,
) -> RevisionSummary raise {
  require_post_version(read_post(input, name), expected)
  prepare_authoring_vault(input, ".moonpress-trash") |> ignore
  let content = open_authoring_subdirectory(input, "content")
  defer directory_close(content.fd)
  content.lock()
  if content.kind(".moonpress-edit") != 0 {
    raise InvalidInput(
      "Interrupted article editing must be inspected before moving to trash",
    )
  }
  let snapshot = read_post_at(content, name)
  require_post_version(snapshot, expected)
  let vault = open_authoring_subdirectory(input, ".moonpress-trash")
  defer directory_close(vault.fd)
  vault.lock()
  let record = store_authoring_record(vault, name, snapshot.content)
  require_post_version(read_post_at(content, name), expected)
  content.remove(name)
  record.revision
}

///|
pub fn list_trashed_posts(input : String) -> Array[RevisionSummary] raise {
  vault_records(input, ".moonpress-trash", None)
}

///|
pub fn read_trashed_post(input : String, id : String) -> RevisionSnapshot raise {
  let vault = open_authoring_subdirectory(input, ".moonpress-trash")
  defer directory_close(vault.fd)
  vault.lock()
  read_authoring_record(vault, id)
}

///|
pub fn restore_trashed_post(
  input : String,
  id : String,
  expected_record : String,
) -> SavePostReport raise {
  if !valid_digest(expected_record) {
    raise InvalidInput("Expected trash-record digest must be lowercase SHA-256")
  }
  let content = open_authoring_subdirectory(input, "content")
  defer directory_close(content.fd)
  content.lock()
  if content.kind(".moonpress-edit") != 0 {
    raise InvalidInput(
      "Interrupted article editing must be inspected before restoring trash",
    )
  }
  let vault = open_authoring_subdirectory(input, ".moonpress-trash")
  defer directory_close(vault.fd)
  vault.lock()
  let record = read_authoring_record(vault, id)
  if record.revision.record_digest != expected_record {
    raise InvalidInput("Trash record changed; inspect again")
  }
  let name = record.revision.name
  if content.kind(name) != 0 {
    raise InvalidInput(
      "Original article filename is occupied; existing source and trash retained",
    )
  }
  content.write_new(name, @utf8.encode(record.content), private_mode=true)
  if read_post_at(content, name).digest != record.revision.digest {
    raise InvalidInput("Restored source changed; trash retained")
  }
  if read_authoring_record(vault, id).revision.record_digest != expected_record {
    raise InvalidInput(
      "Trash record changed; restored article and trash retained",
    )
  }
  vault.remove(id)
  { source: "content/" + name, digest: record.revision.digest, changed: true, }
}

///|
pub(all) struct TrashPurgeReport {
  id : String
  name : String
  purged : Bool
} derive(ToJson)

///|
pub extend TrashPurgeReport with ToJson::{to_json}

///|
pub fn purge_trashed_post(
  input : String,
  id : String,
  expected_record : String,
  acknowledged : Bool,
) -> TrashPurgeReport raise {
  if !acknowledged || !valid_digest(expected_record) {
    raise InvalidInput(
      "Permanent purge requires acknowledgement and the inspected record digest",
    )
  }
  let vault = open_authoring_subdirectory(input, ".moonpress-trash")
  defer directory_close(vault.fd)
  vault.lock()
  let record = read_authoring_record(vault, id)
  if record.revision.record_digest != expected_record {
    raise InvalidInput(
      "Trash record changed; inspect again before permanent purge",
    )
  }
  vault.remove(id)
  { id, name: record.revision.name, purged: true, }
}
