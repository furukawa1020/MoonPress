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
  render_blocks(parse_blocks(source))
}

///|
pub fn page_title(source : String, fallback : String) -> String {
  for block in parse_blocks(source) {
    if block is Heading(1, text) {
      return text.trim().to_owned()
    }
  }
  fallback
}

///|
pub fn apply_layout(
  layout : String,
  title : String,
  body : String,
  description? : String = "",
  toc? : String = "",
) -> String {
  // One pass over the template; inserted values are never parsed again.
  let out = StringBuilder()
  let mut remainder = layout
  while true {
    match remainder.split_once("{{") {
      None => {
        out.write_string(remainder)
        break
      }
      Some((before, tail)) => {
        out.write_string(before.to_owned())
        match tail.to_owned().split_once("}}") {
          None => {
            out.write_string("{{" + tail.to_owned())
            break
          }
          Some((key, after)) => {
            let value = match key.to_owned() {
              "title" => escape_html(title)
              "description" => escape_html(description)
              "content" => body
              "toc" => toc
              other => "{{" + other + "}}"
            }
            out.write_string(value)
            remainder = after.to_owned()
          }
        }
      }
    }
  }
  out.to_string()
}

///|
pub suberror BuildError {
  InvalidInput(String)
}

///|
pub impl Show for BuildError with fn output(self, logger) {
  match self {
    InvalidInput(message) => logger.write_string(message)
  }
}

///|
pub extend BuildError with Show::{to_string, output}
