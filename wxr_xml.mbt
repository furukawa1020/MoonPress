///|
priv struct WxrXml {
  name : String
  attributes : Map[String, String]
  text : String
  children : Array[WxrXml]
}

///|
priv struct WxrReader {
  source : String
  mut offset : Int
  mut nodes : Int
}

///|
fn wxr_decode(text : String) -> String raise {
  let out = StringBuilder()
  let mut rest = text[:]
  while rest.split_once("&") is Some((before, after)) {
    out.write_string(before.to_owned())
    let (entity, next) = match after.split_once(";") {
      Some(pair) => pair
      None => raise InvalidInput("Unclosed XML entity")
    }
    let value = match entity.to_owned() {
      "amp" => "&"
      "lt" => "<"
      "gt" => ">"
      "quot" => "\""
      "apos" => "'"
      value => {
        if !value.has_prefix("#") || value.length() > 12 {
          raise InvalidInput("Unsupported XML entity")
        }
        let hex = value.has_prefix("#x")
        let digits = if hex { value[2:] } else { value[1:] }
        if digits.is_empty() {
          raise InvalidInput("Empty character reference")
        }
        let mut number = 0
        for c in digits {
          let n = c.to_int()
          let digit = if n >= 48 && n <= 57 {
            n - 48
          } else if hex && n >= 65 && n <= 70 {
            n - 55
          } else if hex && n >= 97 && n <= 102 {
            n - 87
          } else {
            raise InvalidInput("Invalid character reference")
          }
          number = number * (if hex { 16 } else { 10 }) + digit
          if number > 0x10FFFF {
            raise InvalidInput("Character reference out of range")
          }
        }
        if number >= 0xD800 && number <= 0xDFFF {
          raise InvalidInput("XML surrogate reference")
        }
        let value = number.unsafe_to_char().to_string()
        require_xml_text(value, "WXR character reference")
        value
      }
    }
    out.write_string(value)
    rest = next
  }
  out.write_string(rest.to_owned())
  out.to_string()
}

///|
fn WxrReader::starts(self : WxrReader, text : String) -> Bool {
  self.source[self.offset:].has_prefix(text)
}

///|
fn WxrReader::space(self : WxrReader) -> Unit {
  while self.offset < self.source.length() &&
        [" ", "\t", "\r", "\n"].contains(
          self.source[self.offset:self.offset + 1].to_owned(),
        ) {
    self.offset += 1
  }
}

///|
fn WxrReader::name(self : WxrReader) -> String raise {
  let start = self.offset
  while self.offset < self.source.length() {
    let c = self.source[self.offset:self.offset + 1].to_owned()
    if !c.all(c => {
        c.is_ascii_alphabetic() ||
        c.is_ascii_digit() ||
        c == '_' ||
        c == '-' ||
        c == ':' ||
        c == '.'
      }) {
      break
    }
    self.offset += 1
  }
  let name = self.source[start:self.offset].to_owned()
  if name.is_empty() || !name[:1].all(c => c.is_ascii_alphabetic() || c == '_') {
    raise InvalidInput("Invalid XML name")
  }
  let parts = name.split(":").to_array()
  if parts.length() > 2 ||
    parts.any(part => {
      part.is_empty() || !part[:1].all(c => c.is_ascii_alphabetic() || c == '_')
    }) {
    raise InvalidInput("Invalid qualified XML name")
  }
  name
}

///|
fn WxrReader::through(self : WxrReader, end : String) -> String raise {
  let tail = self.source[self.offset:]
  let (value, _) = match tail.split_once(end) {
    Some(parts) => parts
    None => raise InvalidInput("Unclosed XML token")
  }
  self.offset += value.length() + end.length()
  value.to_owned()
}

///|
fn WxrReader::comment(self : WxrReader) -> Unit raise {
  self.offset += 4
  let text = self.through("-->")
  if text.contains("--") || text.has_suffix("-") {
    raise InvalidInput("Invalid XML comment")
  }
}

///|
fn WxrReader::element(self : WxrReader, depth : Int) -> WxrXml raise {
  if depth > 32 || self.nodes >= 100000 {
    raise InvalidInput("WXR XML depth/node limit exceeded")
  }
  self.nodes += 1
  if !self.starts("<") {
    raise InvalidInput("Expected XML element")
  }
  self.offset += 1
  let name = self.name()
  let attributes : Map[String, String] = Map([])
  while true {
    let before = self.offset
    self.space()
    if self.starts("/>") {
      self.offset += 2
      return { name, attributes, text: "", children: [], }
    }
    if self.starts(">") {
      self.offset += 1
      break
    }
    if self.offset == before || attributes.length() >= 64 {
      raise InvalidInput("Invalid XML attributes")
    }
    let key = self.name()
    self.space()
    if !self.starts("=") {
      raise InvalidInput("Expected XML attribute assignment")
    }
    self.offset += 1
    self.space()
    if !self.starts("\"") && !self.starts("'") {
      raise InvalidInput("Expected quoted XML attribute")
    }
    let quote = self.source[self.offset:self.offset + 1].to_owned()
    self.offset += 1
    let value = self.through(quote)
    if value.contains("<") || attributes.contains(key) {
      raise InvalidInput("Invalid/duplicate XML attribute")
    }
    attributes[key] = wxr_decode(value)
  }
  let text = StringBuilder()
  let children : Array[WxrXml] = []
  while true {
    if self.starts("</") {
      self.offset += 2
      if self.name() != name {
        raise InvalidInput("Mismatched XML closing tag")
      }
      self.space()
      if !self.starts(">") {
        raise InvalidInput("Invalid XML close")
      }
      self.offset += 1
      return { name, attributes, text: text.to_string(), children, }
    } else if self.starts("<!--") {
      self.comment()
    } else if self.starts("<![CDATA[") {
      self.offset += 9
      text.write_string(self.through("]]>"))
    } else if self.starts("<!") || self.starts("<?") {
      raise InvalidInput(
        "DTD, declarations and processing instructions are not accepted",
      )
    } else if self.starts("<") {
      children.push(self.element(depth + 1))
    } else {
      let tail = self.source[self.offset:]
      let (value, _) = match tail.split_once("<") {
        Some(parts) => parts
        None => raise InvalidInput("Unclosed XML element")
      }
      if value.contains("]]>") {
        raise InvalidInput("Invalid XML text")
      }
      text.write_string(wxr_decode(value.to_owned()))
      self.offset += value.length()
    }
  } nobreak {
    raise InvalidInput("Unclosed XML element")
  }
}

///|
fn parse_wxr_xml(source : String) -> WxrXml raise {
  if @utf8.encode(source).length() > 16777216 {
    raise InvalidInput("WXR input exceeds 16 MiB")
  }
  require_xml_text(source, "WXR")
  let source = source
    .replace_all(old="\r\n", new="\n")
    .replace_all(old="\r", new="\n")
  let reader = {
    source,
    offset: if source.has_prefix("\uFEFF") {
      1
    } else {
      0
    },
    nodes: 0,
  }
  if reader.starts("<?xml ") {
    reader.offset += 6
    let declaration = reader.through("?>").to_lower()
    if declaration.contains("encoding") &&
      !declaration.contains("encoding=\"utf-8\"") &&
      !declaration.contains("encoding='utf-8'") {
      raise InvalidInput("Only UTF-8 XML is supported")
    }
  }
  reader.space()
  while reader.starts("<!--") {
    reader.comment()
    reader.space()
  }
  let root = reader.element(0)
  reader.space()
  while reader.starts("<!--") {
    reader.comment()
    reader.space()
  }
  if reader.offset != source.length() {
    raise InvalidInput("Unexpected data after XML root")
  }
  root
}

///|
fn WxrXml::field(self : WxrXml, name : String) -> String raise {
  let found = self.children.filter(child => child.name == name)
  if found.length() > 1 {
    raise InvalidInput("Duplicate WXR field: " + name)
  }
  if found.length() == 0 {
    return ""
  }
  if !found[0].children.is_empty() {
    raise InvalidInput("Unexpected markup in WXR field: " + name)
  }
  found[0].text
}
