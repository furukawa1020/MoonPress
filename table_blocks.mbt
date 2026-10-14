///|
priv struct TableData {
  header : Array[String]
  alignment : Array[String]
  rows : Array[Array[String]]
}

///|
// Split only unescaped pipes outside closed inline code. Preserve original
// inline syntax so rendering and reference inspection can use the same parser.
fn table_row(line : String) -> Array[String]? {
  let text = line.trim(chars=" \t").to_owned()
  let cells : Array[String] = []
  let mut cell = StringBuilder()
  let mut offset = 0
  let mut pipe = false
  while offset < text.length() {
    if text[offset:offset + 1] == "\\" {
      let width = escape_width(text, offset)
      cell.write_string(text[offset:offset + width].to_owned())
      offset += width
    } else if text[offset:offset + 1] == "`" {
      let run = backtick_run(text, offset)
      let end = match close_code_span(text, offset + run, run) {
        Some(end) => end + run
        None => offset + run
      }
      cell.write_string(text[offset:end].to_owned())
      offset = end
    } else if text[offset:offset + 1] == "|" {
      pipe = true
      cells.push(cell.to_string().trim(chars=" \t").to_owned())
      cell = StringBuilder()
      offset += 1
    } else {
      let c = text.get_char(offset).unwrap()
      cell.write_char(c)
      offset += if c.to_int() > 65535 { 2 } else { 1 }
    }
  }
  if !pipe {
    return None
  }
  cells.push(cell.to_string().trim(chars=" \t").to_owned())
  let first = if text.has_prefix("|") && cells[0].is_empty() { 1 } else { 0 }
  let end = cells.length() -
    (if text.has_suffix("|") && cells[cells.length() - 1].is_empty() {
      1
    } else {
      0
    })
  let result : Array[String] = []
  for index = first; index < end; index = index + 1 {
    result.push(cells[index])
  }
  if result.is_empty() {
    None
  } else {
    Some(result)
  }
}

///|
fn table_alignment(line : String) -> Array[String]? {
  let cells = match table_row(line) {
    Some(cells) => cells
    None => return None
  }
  let result : Array[String] = []
  for cell in cells {
    let left = cell.has_prefix(":")
    let right = cell.has_suffix(":")
    let start = if left { 1 } else { 0 }
    let end = cell.length() - (if right { 1 } else { 0 })
    if end - start < 3 || !cell[start:end].to_owned().all(c => c == '-') {
      return None
    }
    result.push(
      if left && right {
        "center"
      } else if left {
        "left"
      } else if right {
        "right"
      } else {
        ""
      },
    )
  }
  Some(result)
}

///|
fn table_start(header : String, delimiter : String) -> TableData? {
  match (table_row(header), table_alignment(delimiter)) {
    (Some(header), Some(alignment)) if header.length() == alignment.length() =>
      Some({ header, alignment, rows: [], })
    _ => None
  }
}

///|
fn table_inline_lines(table : TableData) -> Array[String] {
  let lines = table.header.map(cell => cell)
  for row in table.rows {
    for cell in row {
      lines.push(cell)
    }
  }
  lines
}

///|
fn render_table(table : TableData) -> String {
  let out = StringBuilder()
  out.write_string("<table>\n<thead>\n<tr>")
  for index = 0; index < table.header.length(); index = index + 1 {
    out.write_string(
      table_cell("th", table.header[index], table.alignment[index]),
    )
  }
  out.write_string("</tr>\n</thead>\n<tbody>\n")
  for row in table.rows {
    out.write_string("<tr>")
    for index = 0; index < row.length(); index = index + 1 {
      out.write_string(table_cell("td", row[index], table.alignment[index]))
    }
    out.write_string("</tr>\n")
  }
  out.write_string("</tbody>\n</table>\n")
  out.to_string()
}

///|
fn table_cell(tag : String, text : String, alignment : String) -> String {
  let scope = if tag == "th" { " scope=\"col\"" } else { "" }
  let style = if alignment.is_empty() {
    ""
  } else {
    " style=\"text-align:" + alignment + "\""
  }
  "<" + tag + scope + style + ">" + render_inline(text) + "</" + tag + ">"
}
