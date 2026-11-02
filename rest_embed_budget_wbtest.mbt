///|
test "embed cache rejects count exhaustion without dispatch" {
  let cache : Map[String, Json] = Map([])
  for n = 0; n < 256; n = n + 1 {
    cache[n.to_string()] = n.to_json()
  }
  let state : RestEmbedState = { cache, bytes: 0, expanded_bytes: 0, }
  let refused = try {
    rest_embed_fetch(
      "unused",
      "http://example.test/wp-json/wp/v2/users/1",
      "author",
      "http://example.test/",
      None,
      state,
    )
    |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(refused)
  assert_eq(
    rest_embed_fetch(
      "unused",
      "1",
      "author",
      "http://example.test/",
      None,
      state,
    ),
    (1).to_json(),
  )
}

///|
test "embed byte and repeated-cache expansion limits reject without insertion" {
  let state : RestEmbedState = {
    cache: Map([]),
    bytes: 8388608,
    expanded_bytes: 0,
  }
  let refused = try {
    rest_embed_cache(state, "new", "x".to_json()) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(refused)
  assert_eq(state.cache.length(), 0)
  let state : RestEmbedState = {
    cache: Map([]),
    bytes: 0,
    expanded_bytes: 16777215,
  }
  let refused = try {
    rest_embed_cache(state, "new", "x".to_json()) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(refused)
  assert_eq(state.cache.length(), 0)
  assert_eq(state.bytes, 0)
  let state : RestEmbedState = { cache: Map([]), bytes: 0, expanded_bytes: 0, }
  rest_embed_cache(state, "key", "é".to_json()) |> ignore
  assert_eq(state.bytes, 4)
  rest_embed_fetch(
    "unused",
    "key",
    "author",
    "http://example.test/",
    None,
    state,
  )
  |> ignore
  assert_eq(state.bytes, 4)
  assert_eq(state.expanded_bytes, 8)
}
