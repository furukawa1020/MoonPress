///|
priv enum Block {
  Heading(Int, String)
  Paragraph(Array[String])
  CodeBlock(String)
  UnorderedList(Array[String])
  OrderedList(String, Array[String])
  Quote(Array[String])
}

///|
fn heading_level(line : String) -> Int {
  for n = 1; n <= 6; n = n + 1 {
    if line.has_prefix(String::make(n, '#') + " ") {
      return n
    }
  }
  0
}

///|
// A group is paragraph (0), unordered list (1), ordered list (2), or quote (3).
// Only markers at column zero are syntax; indented/nested content is literal.
fn group_line(line : String) -> (Int, String, String) {
  for marker in ["- ", "* ", "+ "] {
    if line.has_prefix(marker) {
      return (1, "", line[2:].to_owned())
    }
  }
  if line == ">" {
    return (3, "", "")
  }
  if line.has_prefix("> ") {
    return (3, "", line[2:].to_owned())
  }
  if line.split_once(". ") is Some((number, text)) {
    let number = number.to_owned()
    if !number.is_empty() &&
      number.length() <= 9 &&
      number.all(c => c >= '0' && c <= '9') {
      let start = number.trim_start(chars="0").to_owned()
      return (2, if start.is_empty() { "0" } else { start }, text.to_owned())
    }
  }
  (0, "", line)
}

///|
fn group_block(kind : Int, start : String, lines : Array[String]) -> Block {
  match kind {
    1 => UnorderedList(lines)
    2 => OrderedList(start, lines)
    3 => Quote(lines)
    _ => Paragraph(lines)
  }
}

///|
fn parse_blocks(source : String) -> Array[Block] {
  let blocks : Array[Block] = []
  let mut lines : Array[String] = []
  let mut kind = 0
  let mut start = ""
  let mut fenced = false
  let mut code = StringBuilder()
  for raw in source.split("\n") {
    let line = raw.to_owned().trim_end(chars="\r").to_owned()
    if line.has_prefix("```") {
      if !lines.is_empty() {
        blocks.push(group_block(kind, start, lines))
        lines = []
      }
      if fenced {
        blocks.push(CodeBlock(code.to_string()))
        code = StringBuilder()
      }
      fenced = !fenced
    } else if fenced {
      code.write_string(line + "\n")
    } else {
      let level = heading_level(line)
      if line.trim().is_empty() || level > 0 {
        if !lines.is_empty() {
          blocks.push(group_block(kind, start, lines))
          lines = []
        }
        if level > 0 {
          blocks.push(Heading(level, line[level + 1:].to_owned()))
        }
      } else {
        let (next_kind, next_start, text) = group_line(line)
        if !lines.is_empty() && next_kind != kind {
          blocks.push(group_block(kind, start, lines))
          lines = []
        }
        if lines.is_empty() {
          kind = next_kind
          start = next_start
        }
        lines.push(text)
      }
    }
  }
  if !lines.is_empty() {
    blocks.push(group_block(kind, start, lines))
  }
  if fenced {
    blocks.push(CodeBlock(code.to_string()))
  }
  blocks
}

///|
fn inline_lines(block : Block) -> Array[String] {
  match block {
    Heading(_, text) => [text]
    Paragraph(lines)
    | UnorderedList(lines)
    | OrderedList(_, lines)
    | Quote(lines) => lines
    CodeBlock(_) => []
  }
}

///|
fn render_blocks(blocks : Array[Block]) -> String {
  let out = StringBuilder()
  let outline = block_headings(blocks)
  let mut heading_index = 0
  for block in blocks {
    match block {
      Heading(level, text) => {
        let id = outline[heading_index].id
        heading_index += 1
        out.write_string(
          "<h\{level} id=\"" +
          escape_html(id) +
          "\">" +
          render_inline(text) +
          "</h\{level}>\n",
        )
      }
      Paragraph(lines) =>
        out.write_string("<p>" + lines.map(render_inline).join("\n") + "</p>\n")
      UnorderedList(items) =>
        out.write_string("<ul>\n" + render_items(items) + "</ul>\n")
      OrderedList(start, items) => {
        let attr = if start == "1" { "" } else { " start=\"" + start + "\"" }
        out.write_string("<ol" + attr + ">\n" + render_items(items) + "</ol>\n")
      }
      Quote(lines) =>
        out.write_string(
          "<blockquote>\n<p>" +
          lines.map(render_inline).join("\n") +
          "</p>\n</blockquote>\n",
        )
      CodeBlock(code) =>
        out.write_string("<pre><code>" + escape_html(code) + "</code></pre>\n")
    }
  }
  out.to_string()
}

///|
fn render_items(items : Array[String]) -> String {
  items.map(item => "<li>" + render_inline(item) + "</li>\n").join("")
}
