///|
test "slug parsing preserves explicit Unicode and filename title fallback" {
  assert_true(@moonpress.parse_document("# Title", "file").slug is None)
  for slug in ["hello-world", "月", "a_b", "v1.2", String::make(250, 'x')] {
    let source = "---\n" +
      { "slug": slug }.to_json().stringify() +
      "\n---\nbody"
    let doc = @moonpress.parse_document(source, "source-name")
    assert_eq(doc.slug, Some(slug))
    assert_eq(doc.title, "source-name")
  }
}

///|
test "unsafe slugs fail including in excluded drafts" {
  for
    slug in [
      "",
      ".",
      "..",
      ".hidden",
      "a/b",
      "a\\b",
      "https:x",
      "with space",
      "月\n",
      "x?y",
      "x#y",
      "x%20",
      String::make(251, 'x'),
      String::make(84, '月'),
    ] {
    let source = "---\n{\"slug\":" +
      slug.to_json().stringify() +
      ",\"draft\":true}\n---\n# Hidden"
    let rejected = try {
      let _ = @moonpress.parse_document(source, "fallback")
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  for value in ["null", "true", "12", "[]"] {
    let rejected = try {
      let _ = @moonpress.parse_document(
        "---\n{\"slug\":" + value + "}\n---\n",
        "file",
      )
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}
