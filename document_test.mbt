///|
test "JSON frontmatter and normalized tags" {
  let doc = @moonpress.parse_document(
    "---\r\n{\"title\":\"月\",\"description\":\"a&b\",\"tags\":[\" MoonBit \",\"MoonBit\",\"開発\"]}\r\n---\r\n# Body",
    "fallback",
  )
  assert_eq(doc.title, "月")
  assert_eq(doc.description, "a&b")
  assert_eq(doc.tags.length(), 2)
  assert_true(doc.tags.contains("MoonBit"))
  assert_true(doc.tags.contains("開発"))
  assert_eq(doc.body, "# Body")
}

///|
test "code fences cannot set page title" {
  let doc = @moonpress.parse_document(
    "```\n# not the title\n```\n# Actual", "fallback",
  )
  assert_eq(doc.title, "Actual")
}

///|
test "automatic titles share visible inline heading text" {
  let source = "~~~\n# Hidden\n~~~\n## Not H1\n# [月](guide.html) `` code ` x `` ![絵](image.svg) & <b>\n# Later"
  assert_eq(@moonpress.page_title(source, "fallback"), "月 code ` x 絵 & <b>")
  assert_eq(
    @moonpress.parse_document(source, "fallback").title,
    "月 code ` x 絵 & <b>",
  )
}

///|
test "empty automatic title uses fallback without selecting a later H1" {
  for source in ["#   \n# Later", "# ![](image.svg)\n# Later", "No heading"] {
    assert_eq(@moonpress.page_title(source, "filename"), "filename")
  }
}

///|
test "explicit titles stay literal and override automatic inline text" {
  let doc = @moonpress.parse_document(
    "---\n{\"title\":\"[literal](url) `code` {{content}}\"}\n---\n# [Auto](guide.html)",
    "fallback",
  )
  assert_eq(doc.title, "[literal](url) `code` {{content}}")
}

///|
test "invalid metadata is rejected" {
  for
    header in [
      "[]", "{\"title\": 42}", "{\"tags\": [false]}", "{\"tags\":[\" \"]}", "{\"titel\":\"typo\"}",
      "{bad}",
    ] {
    let rejected = try {
      @moonpress.parse_document("---\n" + header + "\n---\nText", "x") |> ignore
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
test "template substitutions are single pass" {
  assert_eq(
    @moonpress.apply_layout(
      "{{title}}|{{description}}|{{content}}|{{unknown}}",
      "{{description}}",
      "{{title}}",
      description="<x>",
    ),
    "{{description}}|&lt;x&gt;|{{title}}|{{unknown}}",
  )
}

///|
test "draft metadata is strictly boolean and defaults to published" {
  assert_false(@moonpress.parse_document("# Public", "x").draft)
  assert_false(
    @moonpress.parse_document("---\n{\"draft\":false}\n---\n# Public", "x").draft,
  )
  assert_true(
    @moonpress.parse_document("---\n{\"draft\":true}\n---\n# Draft", "x").draft,
  )
  for value in ["null", "1", "\"true\"", "[]"] {
    let rejected = try {
      @moonpress.parse_document(
        "---\n{\"draft\":" + value + "}\n---\n# Draft",
        "x",
      )
      |> ignore
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}
