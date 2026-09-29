///|
priv struct LayoutTemplate {
  source : String
  content : String
  digest : String
  links : Array[String]
  images : Array[String]
}

///|
priv struct LayoutCatalog {
  default : LayoutTemplate
  named : Map[String, LayoutTemplate]
  used : Array[LayoutTemplate]
}

///|
fn valid_layout_name(name : String) -> Bool {
  safe_output_name(name) &&
  name.has_suffix(".html") &&
  name.length() > 5 &&
  !name.has_prefix(".") &&
  !name.any(c => c.is_whitespace() || c.is_control())
}

///|
fn read_layout(input : String, source : String) -> LayoutTemplate raise {
  let path = input + "/" + source
  require_input_kind(path, 1)
  let content = read_text(path)
  if !content.contains("{{content}}") {
    raise InvalidInput(source + " must contain {{content}}")
  }
  let (links, images) = (template_links(content), template_sources(content)) catch {
    error => raise InvalidInput(source + ": \{error}")
  }
  { source, content, digest: digest_text(content), links, images, }
}

///|
fn load_layouts(input : String) -> LayoutCatalog raise {
  if path_kind(input + "/layouts") != 0 {
    require_input_kind(input + "/layouts", 2)
  }
  let default = read_layout(input, "layout.html")
  { default, named: Map([]), used: [default], }
}

///|
fn select_layout(
  catalog : LayoutCatalog,
  input : String,
  name : String?,
) -> LayoutTemplate raise {
  match name {
    None => catalog.default
    Some(name) => {
      // Keep path validation here too: the catalog must never read outside layouts/.
      if !valid_layout_name(name) {
        raise InvalidInput("Invalid layout filename: " + name)
      }
      if catalog.named.get(name) is Some(template) {
        return template
      }
      require_input_kind(input + "/layouts", 2)
      let template = read_layout(input, "layouts/" + name)
      catalog.named[name] = template
      catalog.used.push(template)
      template
    }
  }
}

///|
fn validate_layouts(
  catalog : LayoutCatalog,
  page_layouts : Map[String, LayoutTemplate],
  routes : Array[String],
  route_lookup : Map[String, Bool],
  heading_targets : Map[String, Map[String, Bool]],
  base_path : String,
) -> Unit raise {
  for template in catalog.used {
    validate_route_links(
      template.images,
      route_lookup,
      sources=true,
      base_path~,
      source=template.source,
    )
    validate_route_links(
      template.links,
      route_lookup,
      base_path~,
      source=template.source,
    )
  }
  for route in routes {
    if route.has_suffix(".html") {
      let template = page_layouts.get(route).unwrap_or(catalog.default)
      validate_heading_links(
        template.links,
        heading_targets,
        route,
        base_path,
        template.source + " (" + route + ")",
      )
    }
  }
}
