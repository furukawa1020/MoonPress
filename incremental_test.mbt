///|
test "SHA256 UTF8 known vector" {
  assert_eq(
    @moonpress.digest_text("abc"),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
}

///|
test "flat output path validation" {
  for
    name in [
      "../x", "a/b", "a\\b", ".", "..", "", ".moonpress.json", "a\nb", "C:x",
    ] {
    assert_false(@moonpress.safe_output_name(name))
  }
  assert_true(@moonpress.safe_output_name("月.html"))
}

///|
test "manifest roundtrip and dependency explanation" {
  let deps : Array[@moonpress.Dependency] = [
    { name: "layout.html", digest: @moonpress.digest_text("a"), },
  ]
  let artifact : @moonpress.Artifact = {
    name: "index.html",
    digest: @moonpress.digest_text("result"),
    dependencies: deps,
  }
  let state = @moonpress.parse_manifest(
    @moonpress.serialize_manifest([artifact]),
  )
  assert_true(state.artifacts == [artifact])
  assert_eq(@moonpress.rebuild_reason(Some(artifact), deps), None)
  assert_eq(@moonpress.rebuild_reason(None, deps), Some("new output"))
  assert_eq(
    @moonpress.rebuild_reason(Some(artifact), [
      { name: "layout.html", digest: @moonpress.digest_text("b"), },
    ]),
    Some("changed dependency: layout.html"),
  )
  assert_eq(
    @moonpress.rebuild_reason(Some(artifact), []),
    Some("dependency removed"),
  )
}

///|
test "reject manifest traversal" {
  let unsafe_artifact : @moonpress.Artifact = {
    name: "../precious",
    digest: "",
    dependencies: [],
  }
  let rejected = try {
    @moonpress.parse_manifest(@moonpress.serialize_manifest([unsafe_artifact]))
    |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "output names use UTF8 byte limit" {
  let ascii = StringBuilder()
  let unicode = StringBuilder()
  for i = 0; i < 250; i = i + 1 {
    ascii.write_string("a")
  }
  for i = 0; i < 83; i = i + 1 {
    unicode.write_string("月")
  }
  assert_true(@moonpress.safe_output_name(ascii.to_string() + ".html"))
  assert_false(@moonpress.safe_output_name(ascii.to_string() + "a.html"))
  assert_true(@moonpress.safe_output_name(unicode.to_string() + "a.html"))
  assert_false(@moonpress.safe_output_name(unicode.to_string() + "ab.html"))
}

///|
test "manifest rejects malformed digests and ambiguous dependencies" {
  let hash = @moonpress.digest_text("valid")
  for digest in ["", "abc", hash.to_upper(), hash + "0"] {
    let artifact : @moonpress.Artifact = {
      name: "index.html",
      digest,
      dependencies: [],
    }
    let rejected = try {
      @moonpress.parse_manifest(@moonpress.serialize_manifest([artifact]))
      |> ignore
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  let invalid : Array[Array[@moonpress.Dependency]] = [
    [{ name: "", digest: hash, }],
    [{ name: "content/index.md", digest: "invalid", }],
    [{ name: "same", digest: hash, }, { name: "same", digest: hash, }],
  ]
  for dependencies in invalid {
    let artifact : @moonpress.Artifact = {
      name: "index.html",
      digest: hash,
      dependencies,
    }
    let rejected = try {
      @moonpress.parse_manifest(@moonpress.serialize_manifest([artifact]))
      |> ignore
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}
