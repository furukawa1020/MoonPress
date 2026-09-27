///|
priv enum Block {
  Heading(Int, String)
  Paragraph(Array[String])
  CodeBlock(String)
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
fn parse_blocks(source : String) -> Array[Block] {
  let blocks : Array[Block] = []
  let mut paragraph : Array[String] = []
  let mut fenced = false
  let mut code = StringBuilder()
  for raw in source.split("\n") {
    let line = raw.to_owned().trim_end(chars="\r").to_owned()
    if line.has_prefix("```") {
      if !paragraph.is_empty() {
        blocks.push(Paragraph(paragraph))
        paragraph = []
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
        if !paragraph.is_empty() {
          blocks.push(Paragraph(paragraph))
          paragraph = []
        }
        if level > 0 {
          blocks.push(Heading(level, line[level + 1:].to_owned()))
        }
      } else {
        paragraph.push(line)
      }
    }
  }
  if !paragraph.is_empty() {
    blocks.push(Paragraph(paragraph))
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
    Paragraph(lines) => lines
    CodeBlock(_) => []
  }
}

///|
fn render_blocks(blocks : Array[Block]) -> String {
  let out = StringBuilder()
  for block in blocks {
    match block {
      Heading(level, text) =>
        out.write_string("<h\{level}>" + render_inline(text) + "</h\{level}>\n")
      Paragraph(lines) =>
        out.write_string("<p>" + lines.map(render_inline).join("\n") + "</p>\n")
      CodeBlock(code) =>
        out.write_string("<pre><code>" + escape_html(code) + "</code></pre>\n")
    }
  }
  out.to_string()
}
