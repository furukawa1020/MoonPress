///|
fn html_table_elements(nodes : Array[IntakeHtml]) -> Array[IntakeHtml] raise {
  let result : Array[IntakeHtml] = []
  for node in nodes {
    match node {
      Text(text) if text.trim().is_empty() => ()
      Element(_, _, _) => result.push(node)
      _ => raise InvalidInput("Unexpected table text")
    }
  }
  result
}

///|
fn html_table_cells(row : IntakeHtml, tag : String) -> Array[String] raise {
  let children = match row {
    Element("tr", attrs, children) if attrs.is_empty() => children
    _ => raise InvalidInput("Expected plain table row")
  }
  let cells : Array[String] = []
  for cell in html_table_elements(children) {
    match cell {
      Element(name, attrs, children) if name == tag => {
        if attrs.keys().any(key => key != "scope" || tag != "th") ||
          (attrs.contains("scope") && attrs.get("scope") != Some("col")) {
          raise InvalidInput("Unsupported table cell attributes")
        }
        let empty = children.all(child => {
          match child {
            Text(text) => text.trim().is_empty()
            _ => false
          }
        })
        cells.push(if empty { "" } else { html_inline_checked(children) })
      }
      _ => raise InvalidInput("Table header/body cells disagree")
    }
  }
  if cells.is_empty() || cells.length() > 32 {
    raise InvalidInput("Table width bound")
  }
  cells
}

///|
fn html_table(
  attrs : Map[String, String],
  children : Array[IntakeHtml],
) -> String raise {
  if !attrs.is_empty() {
    raise InvalidInput("Unsupported table attributes")
  }
  let roots = html_table_elements(children)
  if roots.is_empty() {
    raise InvalidInput("Missing table header")
  }
  let rows : Array[IntakeHtml] = match roots[0] {
    Element("thead", attrs, children) if attrs.is_empty() => {
      let rows = html_table_elements(children)
      if rows.length() != 1 || roots.length() > 2 {
        raise InvalidInput("Expected one table header row")
      }
      if roots.length() == 2 {
        match roots[1] {
          Element("tbody", attrs, children) if attrs.is_empty() =>
            for row in html_table_elements(children) {
              rows.push(row)
            }
          _ => raise InvalidInput("Expected table body")
        }
      }
      rows
    }
    _ => roots
  }
  if rows.length() > 1001 {
    raise InvalidInput("Table row bound")
  }
  let header = html_table_cells(rows[0], "th")
  let body : Array[Array[String]] = []
  for i = 1; i < rows.length(); i = i + 1 {
    let cells = html_table_cells(rows[i], "td")
    if cells.length() != header.length() {
      raise InvalidInput("Ragged HTML table")
    }
    body.push(cells)
  }
  let out = StringBuilder()
  out.write_string("| " + header.join(" | ") + " |\n|")
  for _ in header {
    out.write_string(" --- |")
  }
  out.write_string("\n")
  for row in body {
    out.write_string("| " + row.join(" | ") + " |\n")
  }
  let markdown = out.to_string()
  let table : TableData = {
    header,
    alignment: header.map(_ => ""),
    rows: body,
  }
  if render_markdown(markdown) != render_table(table) {
    raise InvalidInput("HTML table cannot round-trip through native Markdown")
  }
  markdown
}
