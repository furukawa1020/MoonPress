///|
test "REST credentials require canonical bounded Basic encoding" {
  let (login, secret) = rest_basic(
    "Basic YWxpY2U6MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMA==",
  )
  assert_eq(login, "alice")
  assert_eq(secret, "0".repeat(64))
  for
    value in [
      "Basic YWxpY2U6MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMB==",
      "Basic YTpi",
      "Basic AA==",
      "Basic AB==",
      "Basic AA=A",
      "Basic A===",
      "Basic !!!!",
      "Basic AAA",
      "Bearer x",
      "Basic " + "A".repeat(176),
    ] {
    let rejected = try {
      rest_basic(value) |> ignore
      false
    } catch {
      _ => true
    }
    assert_true(rejected, msg=value)
  }
}

///|
test "native REST identity metadata is exact positive integer and nonnegative owner" {
  let document = parse_document(
    "---\n{\"wp_id\":2147483647,\"author\":0}\n---\n# Title", "fallback",
  )
  assert_eq(document.wp_id, Some(2147483647))
  assert_eq(document.author, 0)
  for
    metadata in [
      "{\"wp_id\":0}", "{\"wp_id\":1.5}", "{\"wp_id\":2147483648}", "{\"author\":-1}",
      "{\"author\":\"1\"}",
    ] {
    let rejected = try {
      parse_document("---\n" + metadata + "\n---\n# Title", "fallback")
      |> ignore
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
test "REST target rejects duplicate query and preserves encoded slug" {
  let (_, query) = rest_target("/wp-json/wp/v2/posts?slug=%E6%9C%88")
  assert_eq(query.get("slug"), Some("月"))
  let duplicate = try {
    rest_target("/wp-json/wp/v2/posts?page=1&page=2") |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(duplicate)
}

///|
test "named native terms normalize deterministically" {
  assert_eq(rest_named_terms([" 月 ", "News", "月"].to_json()), [
    "月", "News",
  ])
  assert_eq(rest_named_terms(([] : Array[String]).to_json()), [])
}

///|
test "native preconditions reject missing malformed and stale versions" {
  let digest = "a".repeat(64)
  assert_eq(rest_precondition(None, digest).unwrap().code, 428)
  assert_eq(rest_precondition(Some("*"), digest).unwrap().code, 400)
  assert_eq(
    rest_precondition(Some("\"" + "b".repeat(64) + "\""), digest).unwrap().code,
    412,
  )
  assert_true(rest_precondition(Some("\"" + digest + "\""), digest) is None)
}

///|
test "upload base64 decoder requires canonical padding" {
  assert_eq(native_base64("AAH/"), b"\x00\x01\xff")
  assert_eq(native_base64("AA=="), b"\x00")
  for value in ["", "AB==", "AA=A", "A===", "AAAA=", "!!!!", "AA==AAAA"] {
    let refused = try {
      native_base64(value) |> ignore
      false
    } catch {
      _ => true
    }
    assert_true(refused)
  }
}
