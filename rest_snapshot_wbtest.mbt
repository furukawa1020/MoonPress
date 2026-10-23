///|
test "REST collection rendering uses the captured publication instant" {
  let document = parse_document(
    "---\n{\"wp_id\":1,\"publish_at\":\"2099-01-01T00:00:00Z\"}\n---\n# Scheduled",
    "scheduled",
  )
  for
    (date, expected) in [
      ("2098-12-31T23:59:59Z", "future"),
      ("2099-01-01T00:00:00Z", "publish"),
    ] {
    let value = rest_edit_value(
      document,
      "scheduled",
      "https://example.test/",
      digest_text("snapshot"),
      instant=publication_timestamp(date),
    )
    let fields = match value {
      Object(fields) => fields
      _ => Map([])
    }
    assert_eq(fields.get("status"), Some(expected.to_json()))
  }
}
