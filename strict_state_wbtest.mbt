///|
test "ownership manifests reject unknown fields at every object level" {
  let artifact : Artifact = {
    name: "a.html",
    digest: digest_text("a"),
    dependencies: [{ name: "source", digest: digest_text("source"), }],
  }
  let manifest = serialize_manifest([artifact])
  for level in [0, 1, 2] {
    let value = @json.parse(manifest)
    let fields = strict_json_object(
      value,
      ["schema", "compiler", "artifacts"],
      "test",
    )
    let target = match (level, fields.get("artifacts")) {
      (0, _) => fields
      (1, Some(Array(items))) =>
        strict_json_object(items[0], ["name", "digest", "dependencies"], "test")
      (_, Some(Array(items))) => {
        let artifact_fields = strict_json_object(
          items[0],
          ["name", "digest", "dependencies"],
          "test",
        )
        match artifact_fields.get("dependencies") {
          Some(Array(deps)) =>
            strict_json_object(deps[0], ["name", "digest"], "test")
          _ => abort("fixture")
        }
      }
      _ => abort("fixture")
    }
    target["unexpected"] = true.to_json()
    assert_true(
      try {
        let _ = parse_manifest(value.stringify())
        false
      } catch {
        _ => true
      },
    )
    assert_true(
      try {
        let _ = compare_manifests(manifest, value.stringify())
        false
      } catch {
        _ => true
      },
    )
  }
  assert_eq(parse_manifest(manifest).artifacts.length(), 1)
}

///|
test "publication journals reject unknown fields and embedded manifest extensions" {
  let manifest = serialize_manifest([])
  let journal : PublicationJournal = {
    schema: 1,
    previous: Some(manifest),
    next: manifest,
    present: [],
    writes: [],
  }
  let value = ToJson::to_json(journal)
  let fields = strict_json_object(
    value,
    ["schema", "previous", "next", "present", "writes"],
    "test",
  )
  fields["unexpected"] = true.to_json()
  assert_true(
    try {
      let _ = parse_journal(value.stringify())
      false
    } catch {
      _ => true
    },
  )
  for field in ["previous", "next"] {
    let value = ToJson::to_json(journal)
    let fields = strict_json_object(
      value,
      ["schema", "previous", "next", "present", "writes"],
      "test",
    )
    fields[field] = "{\"schema\":1,\"compiler\":\"moonpress-0.1\",\"artifacts\":[],\"unexpected\":true}".to_json()
    assert_true(
      try {
        let _ = parse_journal(value.stringify())
        false
      } catch {
        _ => true
      },
    )
  }
  assert_eq(parse_journal(ToJson::to_json(journal).stringify()).schema, 1)
}
