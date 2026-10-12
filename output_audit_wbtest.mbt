///|
test "output audit compares exact binary digests" {
  let bytes = b"\x00\xffbinary"
  let artifact : Artifact = {
    name: "a.pdf",
    digest: digest_bytes(bytes),
    dependencies: [],
  }
  let intact = output_digest_finding(artifact, bytes)
  assert_eq(intact.status, "intact")
  assert_eq(intact.expected, intact.actual)
  let edited = output_digest_finding(artifact, b"changed")
  assert_eq(edited.path, "a.pdf")
  assert_eq(edited.status, "edited")
  assert_eq(edited.expected, Some(artifact.digest))
  assert_eq(edited.actual, Some(digest_bytes(b"changed")))
}

///|
test "audit rejects absent or invalid directory targets without creating paths" {
  for output in ["", "/", "/moonpress-audit-nonexistent-root-164"] {
    let rejected = try {
      let _ = audit_output(output)
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}
