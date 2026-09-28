///|
test "publication journal roundtrips prior presence and exact manifests" {
  let old = serialize_manifest([
    { name: "月.html", digest: digest_text("old"), dependencies: [], },
    { name: "missing.css", digest: digest_text("css"), dependencies: [], },
  ])
  let next = serialize_manifest([
    { name: "月.html", digest: digest_text("new"), dependencies: [], },
  ])
  let journal : PublicationJournal = {
    schema: 1,
    previous: Some(old),
    next,
    present: ["月.html"],
    writes: ["月.html"],
  }
  assert_eq(
    ToJson::to_json(parse_journal(ToJson::to_json(journal).stringify())).stringify(),
    ToJson::to_json(journal).stringify(),
  )
  let fresh : PublicationJournal = {
    schema: 1,
    previous: None,
    next,
    present: [],
    writes: ["月.html"],
  }
  assert_eq(
    ToJson::to_json(parse_journal(ToJson::to_json(fresh).stringify())).stringify(),
    ToJson::to_json(fresh).stringify(),
  )
}

///|
fn reject_journal(journal : PublicationJournal) -> Unit raise {
  let rejected = try {
    parse_journal(ToJson::to_json(journal).stringify()) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "publication journal rejects unsupported schema and invalid manifests" {
  let empty = serialize_manifest([])
  reject_journal({
    schema: 2,
    previous: None,
    next: empty,
    present: [],
    writes: [],
  })
  reject_journal({
    schema: 1,
    previous: Some("{}"),
    next: empty,
    present: [],
    writes: [],
  })
  reject_journal({
    schema: 1,
    previous: None,
    next: "{}",
    present: [],
    writes: [],
  })
}

///|
test "publication journal rejects unsafe duplicate and inconsistent names" {
  let manifest = serialize_manifest([
    { name: "index.html", digest: digest_text("old"), dependencies: [], },
  ])
  for names in [["../precious"], ["index.html", "index.html"], ["ghost.html"]] {
    reject_journal({
      schema: 1,
      previous: Some(manifest),
      next: manifest,
      present: names,
      writes: ["index.html"],
    })
    reject_journal({
      schema: 1,
      previous: Some(manifest),
      next: manifest,
      present: ["index.html"],
      writes: names,
    })
  }
  reject_journal({
    schema: 1,
    previous: None,
    next: manifest,
    present: ["index.html"],
    writes: ["index.html"],
  })
  reject_journal({
    schema: 1,
    previous: Some(manifest),
    next: manifest,
    present: [],
    writes: [],
  })
  let changed = serialize_manifest([
    { name: "index.html", digest: digest_text("new"), dependencies: [], },
  ])
  reject_journal({
    schema: 1,
    previous: Some(manifest),
    next: changed,
    present: ["index.html"],
    writes: [],
  })
  for name in ["journal", "backup"] {
    let next = serialize_manifest([
      { name, digest: digest_text("bytes"), dependencies: [], },
    ])
    reject_journal({
      schema: 1,
      previous: None,
      next,
      present: [],
      writes: [name],
    })
  }
}
