///|
pub(all) struct HeadingInfo {
  level : Int
  text : String
  id : String
} derive(Eq)

///|
pub extend HeadingInfo with Eq::{equal, not_equal}

///|
pub fn headings(source : String) -> Array[HeadingInfo] {
  block_headings(parse_blocks(source))
}

///|
fn heading_slug(text : String) -> String {
  let out = StringBuilder()
  let mut separator = false
  let mut emitted = false
  for c in text.to_lower() {
    if c.is_ascii_alphabetic() ||
      c.is_ascii_digit() ||
      c == '_' ||
      (!c.is_ascii() && !c.is_whitespace() && !c.is_control()) {
      if separator && emitted {
        out.write_char('-')
      }
      out.write_char(c)
      separator = false
      emitted = true
    } else {
      separator = true
    }
  }
  "mp-" + (if emitted { out.to_string() } else { "section" })
}

///|
fn block_headings(blocks : Array[Block]) -> Array[HeadingInfo] {
  let result : Array[HeadingInfo] = []
  let used : Map[String, Bool] = Map([])
  let next : Map[String, Int] = Map([])
  for block in blocks {
    if block is Heading(level, raw) {
      let text = inline_text(raw)
      let base = heading_slug(text)
      let mut id = base
      let mut suffix = next.get(base).unwrap_or(2)
      while used.contains(id) {
        id = base + "-\{suffix}"
        suffix += 1
      }
      next[base] = suffix
      used[id] = true
      result.push({ level, text, id, })
    }
  }
  result
}

///|
pub fn render_toc(source : String) -> String {
  render_outline(headings(source))
}

///|
fn render_outline(outline : Array[HeadingInfo]) -> String {
  if outline.is_empty() {
    return ""
  }
  let out = StringBuilder()
  out.write_string(
    "<nav class=\"toc\" aria-label=\"Table of contents\">\n<ol>\n",
  )
  for heading in outline {
    out.write_string(
      "<li class=\"toc-level-\{heading.level}\"><a href=\"#" +
      url_component(heading.id) +
      "\">" +
      escape_html(heading.text) +
      "</a></li>\n",
    )
  }
  out.write_string("</ol>\n</nav>\n")
  out.to_string()
}
