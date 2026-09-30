///|
priv enum Block {
  Heading(Int, String)
  Paragraph(Array[String])
  CodeBlock(String, String?)
  ThematicBreak
  UnorderedList(Array[String])
  OrderedList(String, Array[String])
  Quote(Array[String])
}

///|
fn is_thematic_break(line : String) -> Bool {
  let marker = match line.get_char(0) {
    Some('-') => '-'
    Some('*') => '*'
    Some('_') => '_'
    _ => return false
  }
  let mut count = 0
  for c in line {
    if c == marker {
      count += 1
    } else if c != ' ' && c != '\t' {
      return false
    }
  }
  count >= 3
}

///|
fn heading_level(line : String) -> Int {
  for n = 1; n <= 6; n = n + 1 {
    let marker = String::make(n, '#')
    if line == marker ||
      line.has_prefix(marker + " ") ||
      line.has_prefix(marker + "\t") {
      return n
    }
  }
  0
}

///|
fn heading_content(line : String, level : Int) -> String {
  let raw = line[level:].to_owned().trim_end(chars=" \t").to_owned()
  let without_hashes = raw.trim_end(chars="#").to_owned()
  let content = if without_hashes.length() < raw.length() &&
    (without_hashes.has_suffix(" ") || without_hashes.has_suffix("\t")) {
    without_hashes
  } else {
    raw
  }
  content.trim(chars=" \t").to_owned()
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
  let mut fence : (String, Int)? = None
  let mut language : String? = None
  let mut code = StringBuilder()
  for raw in source.split("\n") {
    let line = raw.to_owned().trim_end(chars="\r").to_owned()
    if fence is Some((marker, length)) {
      if closes_fence(line, marker, length) {
        blocks.push(CodeBlock(code.to_string(), language))
        code = StringBuilder()
        fence = None
      } else {
        code.write_string(line + "\n")
      }
    } else if opens_fence(line) is Some(opening) {
      if !lines.is_empty() {
        blocks.push(group_block(kind, start, lines))
        lines = []
      }
      fence = Some(opening)
      language = fence_language(line, opening.1)
    } else {
      let level = heading_level(line)
      let separator = is_thematic_break(line)
      if line.trim().is_empty() || level > 0 || separator {
        if !lines.is_empty() {
          blocks.push(group_block(kind, start, lines))
          lines = []
        }
        if separator {
          blocks.push(ThematicBreak)
        } else if level > 0 {
          blocks.push(Heading(level, heading_content(line, level)))
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
  if fence is Some(_) {
    blocks.push(CodeBlock(code.to_string(), language))
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
    CodeBlock(_, _) | ThematicBreak => []
  }
}

///|
fn render_blocks(blocks : Array[Block]) -> String {
  render_blocks_with_headings(blocks, block_headings(blocks))
}

///|
fn render_blocks_with_headings(
  blocks : Array[Block],
  outline : Array[HeadingInfo],
) -> String {
  let out = StringBuilder()
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
      ThematicBreak => out.write_string("<hr>\n")
      CodeBlock(code, language) => {
        let attribute = match language {
          Some(name) => " class=\"language-" + escape_html(name) + "\""
          None => ""
        }
        out.write_string(
          "<pre><code" + attribute + ">" + escape_html(code) + "</code></pre>\n",
        )
      }
    }
  }
  out.to_string()
}

///|
fn render_items(items : Array[String]) -> String {
  items.map(item => "<li>" + render_inline(item) + "</li>\n").join("")
}

///|
// Only ASCII space/tab delimit info tokens. Reject the entire first token if
// unsafe; never turn arbitrary info strings into attributes or executable code.
fn fence_language(line : String, marker_length : Int) -> String? {
  let info = line[marker_length:].to_owned().trim_start(chars=" \t").to_owned()
  let token = StringBuilder()
  let mut length = 0
  for c in info {
    if c == ' ' || c == '\t' {
      break
    }
    if !((c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') ||
      c == '_' ||
      c == '-' ||
      c == '+') {
      return None
    }
    length += 1
    if length > 64 {
      return None
    }
    token.write_char(c)
  }
  if length == 0 {
    None
  } else {
    Some(token.to_string())
  }
}

///|
fn fence_run(line : String) -> (String, Int)? {
  if !line.has_prefix("```") && !line.has_prefix("~~~") {
    return None
  }
  let marker = line[:1].to_owned()
  let mut length = 0
  while length < line.length() && line[length:length + 1] == marker {
    length += 1
  }
  Some((marker, length))
}

///|
fn opens_fence(line : String) -> (String, Int)? {
  match fence_run(line) {
    Some((marker, length)) =>
      // Backticks in a backtick fence's info string are not an opener.
      if marker == "`" && line[length:].to_owned().contains("`") {
        None
      } else {
        Some((marker, length))
      }
    None => None
  }
}

///|
fn closes_fence(line : String, marker : String, minimum : Int) -> Bool {
  match fence_run(line) {
    Some((actual, length)) =>
      actual == marker &&
      length >= minimum &&
      line[length:].to_owned().all(c => c == ' ' || c == '\t')
    None => false
  }
}
