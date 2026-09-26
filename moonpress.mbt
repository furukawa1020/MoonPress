///|
pub fn escape_html(text : String) -> String {
  text
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
  .replace_all(old="\"", new="&quot;")
  .replace_all(old="'", new="&#39;")
}

///|
pub fn render_markdown(source : String) -> String {
  let out = StringBuilder()
  let mut code = false
  let mut paragraph = false
  for raw in source.split("\n") {
    let line = raw.to_owned().trim_end(chars="\r").to_owned()
    if line.has_prefix("```") {
      if paragraph {
        out.write_string("</p>\n")
        paragraph = false
      }
      out.write_string(if code { "</code></pre>\n" } else { "<pre><code>" })
      code = !code
    } else if code {
      out.write_string(escape_html(line) + "\n")
    } else if line.trim().is_empty() {
      if paragraph {
        out.write_string("</p>\n")
        paragraph = false
      }
    } else {
      let mut level = 0
      for n = 1; n <= 6; n = n + 1 {
        if line.has_prefix(String::make(n, '#') + " ") {
          level = n
        }
      }
      if level > 0 {
        if paragraph {
          out.write_string("</p>\n")
          paragraph = false
        }
        out.write_string(
          "<h\{level}>" +
          escape_html(line[level + 1:].to_owned()) +
          "</h\{level}>\n",
        )
      } else {
        if paragraph {
          out.write_string("\n")
        } else {
          out.write_string("<p>")
          paragraph = true
        }
        out.write_string(escape_html(line))
      }
    }
  }
  if paragraph {
    out.write_string("</p>\n")
  }
  if code {
    out.write_string("</code></pre>\n")
  }
  out.to_string()
}

///|
pub fn page_title(source : String, fallback : String) -> String {
  for line in source.split("\n") {
    let text = line.to_owned()
    if text.has_prefix("# ") {
      return text[2:].to_owned().trim().to_owned()
    }
  }
  fallback
}

///|
pub fn apply_layout(layout : String, title : String, body : String) -> String {
  // Substitute in one pass: placeholders inside source content remain literal.
  let parts = layout.split("{{content}}")
  let out = StringBuilder()
  let mut first = true
  for part in parts {
    if !first {
      out.write_string(body)
    }
    out.write_string(
      part.to_owned().replace_all(old="{{title}}", new=escape_html(title)),
    )
    first = false
  }
  out.to_string()
}

///|
pub suberror BuildError {
  InvalidInput(String)
}

///|
pub fn build_site(input : String, output : String) -> Int raise {
  if @fs.path_exists(output) {
    raise InvalidInput(
      "Output already exists: \{output}. Choose a fresh directory; MoonPress never deletes your files.",
    )
  }
  let layout = @fs.read_file_to_string(input + "/layout.html")
  if !layout.contains("{{content}}") {
    raise InvalidInput("layout.html must contain {{content}}")
  }
  let css = @fs.read_file_to_bytes(input + "/style.css")
  let names = @fs.read_dir(input + "/content").to_owned()
  names.sort()
  let pages : Array[(String, String)] = []
  for name in names {
    if name.has_suffix(".md") {
      let path = input + "/content/" + name
      if !@fs.is_file(path) {
        raise InvalidInput("Expected regular file: \{path}")
      }
      let source = @fs.read_file_to_string(path)
      let stem = name[:name.length() - 3].to_owned()
      pages.push(
        (
          stem + ".html",
          apply_layout(
            layout,
            page_title(source, stem),
            render_markdown(source),
          ),
        ),
      )
    }
  }
  if pages.is_empty() {
    raise InvalidInput("No .md pages found")
  }
  // Validate/read everything before creating output. Writes can still fail on disk errors.
  @fs.create_dir(output)
  for page in pages {
    @fs.write_string_to_file(output + "/" + page.0, page.1)
  }
  @fs.write_bytes_to_file(output + "/style.css", css)
  @fs.write_string_to_file(output + "/.nojekyll", "")
  pages.length()
}
