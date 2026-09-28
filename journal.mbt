///|
priv struct PublicationJournal {
  schema : Int
  previous : String?
  next : String
  present : Array[String]
  writes : Array[String]
} derive(ToJson, FromJson)

///|
fn artifact_map(artifacts : Array[Artifact]) -> Map[String, Artifact] {
  let result : Map[String, Artifact] = Map([])
  for artifact in artifacts {
    result[artifact.name] = artifact
  }
  result
}

///|
fn journal_names(names : Array[String]) -> Map[String, Bool] raise {
  let seen : Map[String, Bool] = Map([])
  for name in names {
    if !safe_output_name(name) || seen.contains(name) {
      raise InvalidInput("Invalid or duplicate path in publication journal")
    }
    seen[name] = true
  }
  seen
}

///|
fn parse_journal(text : String) -> PublicationJournal raise {
  let journal : PublicationJournal = @json.from_json(@json.parse(text))
  if journal.schema != 1 {
    raise InvalidInput("Unsupported MoonPress publication journal version")
  }
  let previous = match journal.previous {
    None => Map([])
    Some(text) => artifact_map(parse_manifest(text).artifacts)
  }
  let next = artifact_map(parse_manifest(journal.next).artifacts)
  let present = journal_names(journal.present)
  let writes = journal_names(journal.writes)
  for name in journal.present {
    if !previous.contains(name) {
      raise InvalidInput(
        "Journal presence is not in previous manifest: " + name,
      )
    }
  }
  for name in journal.writes {
    if name == "journal" || name == "backup" || !next.contains(name) {
      raise InvalidInput(
        "Invalid planned write in publication journal: " + name,
      )
    }
  }
  for name, artifact in next {
    if !writes.contains(name) &&
      (!present.contains(name) || previous.get(name) != Some(artifact)) {
      raise InvalidInput("Unrecorded write in publication journal: " + name)
    }
  }
  journal
}
