///|
priv struct AuthoringRecord {
  schema : Int
  name : String
  digest : String
  content : String
  created : Int64
} derive(ToJson, FromJson)

///|
pub(all) struct RevisionSummary {
  id : String
  name : String
  digest : String
  record_digest : String
  bytes : Int
  created : Int64
} derive(ToJson)

///|
pub extend RevisionSummary with ToJson::{to_json}

///|
pub(all) struct RevisionSnapshot {
  revision : RevisionSummary
  content : String
} derive(ToJson)

///|
pub extend RevisionSnapshot with ToJson::{to_json}

///|
extern "C" fn authoring_time() -> Int64 = "moonpress_authoring_time"

///|
fn record_id(name : String, digest : String) -> String {
  digest_text(name) + "-" + digest + ".json"
}

///|
fn require_record_id(id : String) -> Unit raise {
  if id.length() != 134 ||
    !safe_output_name(id) ||
    !id.has_suffix(".json") ||
    id[64:65] != "-" ||
    !valid_digest(id[:64].to_owned()) ||
    !valid_digest(id[65:129].to_owned()) {
    raise InvalidInput("Invalid authoring record ID")
  }
}

///|
fn read_authoring_record(
  directory : AuthoringDirectory,
  id : String,
) -> RevisionSnapshot raise {
  require_record_id(id)
  let bytes = directory.read(id, max_bytes=16777216)
  let value = @json.parse(decode_text(bytes, id))
  let _ = strict_json_object(
    value,
    ["schema", "name", "digest", "content", "created"],
    "authoring record",
  )
  let record : AuthoringRecord = @json.from_json(value)
  require_post_name(record.name)
  if record.schema != 1 ||
    record.created < 0 ||
    @utf8.encode(record.content).length() > 4194304 ||
    digest_text(record.content) != record.digest ||
    record_id(record.name, record.digest) != id {
    raise InvalidInput("Invalid or modified authoring record: " + id)
  }
  {
    revision: {
      id,
      name: record.name,
      digest: record.digest,
      record_digest: digest_bytes(bytes),
      bytes: @utf8.encode(record.content).length(),
      created: record.created,
    },
    content: record.content,
  }
}

///|
fn store_authoring_record(
  directory : AuthoringDirectory,
  name : String,
  content : String,
) -> RevisionSnapshot raise {
  require_post_name(name)
  if @utf8.encode(content).length() > 4194304 {
    raise InvalidInput("Article history/trash content exceeds 4 MiB")
  }
  let digest = digest_text(content)
  let id = record_id(name, digest)
  if directory.kind(id) != 0 {
    let existing = read_authoring_record(directory, id)
    if existing.revision.name != name || existing.content != content {
      raise InvalidInput("Existing authoring record differs; preserved")
    }
    return existing
  }
  let created = authoring_time()
  if created < 0 {
    raise InvalidInput("Cannot read authoring wall clock")
  }
  if @fs.read_dir(directory.path).length() >= 4096 {
    raise InvalidInput("Authoring vault exceeds 4096 entries")
  }
  let record : AuthoringRecord = { schema: 1, name, content, digest, created, }
  let bytes = @utf8.encode(ToJson::to_json(record).stringify() + "\n")
  if bytes.length() > 16777216 {
    raise InvalidInput("Encoded authoring record exceeds 16 MiB")
  }
  directory.write_new(id, bytes, private_mode=true)
  read_authoring_record(directory, id)
}

///|
fn vault_records(
  input : String,
  vault : String,
  name : String?,
) -> Array[RevisionSummary] raise {
  if input.is_empty() {
    raise InvalidInput("Site directory must not be empty")
  }
  require_input_kind(input, 2)
  require_input_kind(input + "/content", 2)
  let path = input + "/" + vault
  if path_kind(path) == 0 {
    return []
  }
  let directory = open_authoring_subdirectory(input, vault)
  defer directory_close(directory.fd)
  directory.lock()
  let names = @fs.read_dir(path).to_owned()
  if names.length() > 4096 {
    raise InvalidInput("Authoring vault exceeds 4096 entries")
  }
  names.sort()
  let result : Array[RevisionSummary] = []
  for id in names {
    let record = read_authoring_record(directory, id)
    if name is None || name == Some(record.revision.name) {
      result.push(record.revision)
    }
  }
  result.sort_by((a, b) => {
    if a.created < b.created {
      -1
    } else if a.created > b.created {
      1
    } else {
      a.id.compare(b.id)
    }
  })
  result
}

///|
pub fn checkpoint_post(
  input : String,
  name : String,
  expected : String,
) -> RevisionSummary raise {
  let content = open_authoring_subdirectory(input, "content")
  defer directory_close(content.fd)
  content.lock()
  let snapshot = read_post_at(content, name)
  require_post_version(snapshot, expected)
  let vault = open_authoring_subdirectory(input, ".moonpress-history")
  defer directory_close(vault.fd)
  vault.lock()
  require_same_authoring_site(content, vault)
  store_authoring_record(vault, name, snapshot.content).revision
}

///|
pub fn list_post_revisions(
  input : String,
  name : String,
) -> Array[RevisionSummary] raise {
  require_post_name(name)
  vault_records(input, ".moonpress-history", Some(name))
}

///|
pub fn read_post_revision(
  input : String,
  id : String,
) -> RevisionSnapshot raise {
  let vault = open_authoring_subdirectory(input, ".moonpress-history")
  defer directory_close(vault.fd)
  vault.lock()
  read_authoring_record(vault, id)
}

///|
pub fn restore_post_revision(
  input : String,
  name : String,
  expected : String,
  id : String,
) -> SavePostReport raise {
  let revision = read_post_revision(input, id)
  if revision.revision.name != name {
    raise InvalidInput("Revision belongs to another article")
  }
  save_post(input, name, expected, revision.content)
}
