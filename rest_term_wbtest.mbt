///|
test "native term IDs are stable taxonomy scoped positive integers" {
  assert_eq(rest_term_id("category", "collision-4962"), 779651567)
  assert_eq(rest_term_id("category", "collision-85199"), 779651567)
  assert_true(rest_term_id("category", "shared") > 0)
  assert_true(
    rest_term_id("category", "shared") != rest_term_id("post_tag", "shared"),
  )
  assert_true(rest_term_id("category", "A") != rest_term_id("category", "a"))
}

///|
test "lossless native term slugs preserve Unicode and punctuation distinctions" {
  assert_eq(rest_term_slug("a"), "term-61")
  assert_eq(rest_term_slug("月"), "term-e69c88")
  assert_true(rest_term_slug("a b") != rest_term_slug("a-b"))
  assert_true(rest_term_slug("A") != rest_term_slug("a"))
  assert_eq(rest_term_slugs(Some("term-61,term-61")), ["term-61"])
}

///|
test "term route parser bounds IDs and accepts only one trailing slash" {
  assert_eq(
    rest_wp_term_target("/wp-json/wp/v2/categories/3"),
    Some(("category", 3)),
  )
  assert_eq(
    rest_wp_term_target("/wp-json/wp/v2/tags/3/"),
    Some(("post_tag", 3)),
  )
  assert_eq(rest_wp_term_target("/wp-json/wp/v2/tags/0"), None)
  assert_eq(rest_wp_term_target("/wp-json/wp/v2/tags/2147483648"), None)
  assert_eq(rest_wp_term_target("/wp-json/wp/v2/tags/3/other"), None)
}

///|
test "term projection escapes names and preserves context field boundaries" {
  let term : RestTerm = {
    id: 7,
    name: "A & B",
    slug: "term-4120262042",
    taxonomy: "category",
    count: 2,
  }
  let view = rest_term_value(term, "https://example.test/")
  let embed = rest_term_value(term, "https://example.test/", context="embed")
  match (view, embed) {
    (Object(fields), Object(compact)) => {
      assert_eq(fields["name"], "A &amp; B".to_json())
      assert_true(fields.contains("count") && fields.contains("parent"))
      assert_true(
        !compact.contains("count") &&
        !compact.contains("description") &&
        !compact.contains("parent"),
      )
      assert_eq(compact["id"], (7).to_json())
      assert_true(compact.contains("_links"))
    }
    _ => fail("Expected term objects")
  }
}

///|
test "public flat term OPTIONS reports only implemented methods and arguments" {
  let options = rest_term_options("/wp-json/wp/v2/tags", Map([]))
  assert_eq(options.code, 200)
  assert_eq(
    rest_term_options("/wp-json/wp/v2/tags", Map([("private", "1")])).code,
    400,
  )
  assert_eq(
    rest_taxonomies("/wp-json/wp/v2/taxonomies", Map([("context", "edit")])).code,
    400,
  )
}
