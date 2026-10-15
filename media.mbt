///|
pub(all) struct MediaItem {
  source : String
  url : String
  bytes : Int
  digest : String
  image : Bool
} derive(ToJson)

///|
pub extend MediaItem with ToJson::{to_json}

///|
pub(all) struct MediaReport {
  items : Array[MediaItem]
} derive(ToJson)

///|
pub extend MediaReport with ToJson::{to_json}

///|
fn public_asset_names(input : String) -> Array[String] raise {
  require_input_kind(input, 2)
  let directory = input + "/public"
  let kind = path_kind(directory)
  if kind == 0 {
    return []
  }
  if kind != 2 {
    raise InvalidInput("public must be a real directory, not a symlink")
  }
  let names = @fs.read_dir(directory).to_owned()
  names.sort()
  for name in names {
    let path = directory + "/" + name
    if path_kind(path) != 1 {
      raise InvalidInput(
        "Expected regular public asset (no subdirectories): " + path,
      )
    }
    if !safe_output_name(name) || !allowed_asset_name(name) {
      raise InvalidInput("Unsupported public asset name: " + name)
    }
  }
  names
}

///|
fn image_asset_name(name : String) -> Bool {
  let lower = name.to_lower()
  [".png", ".jpg", ".jpeg", ".gif", ".webp", ".avif", ".ico", ".svg"].any(suffix => {
    lower.has_suffix(suffix)
  })
}

///|
pub fn list_media(input : String) -> MediaReport raise {
  let items : Array[MediaItem] = []
  for name in public_asset_names(input) {
    let bytes = read_bytes(input + "/public/" + name)
    items.push(media_item(name, bytes))
  }
  { items, }
}

///|
fn media_item(name : String, bytes : Bytes) -> MediaItem {
  {
    source: "public/" + name,
    url: url_component(name),
    bytes: bytes.length(),
    digest: digest_bytes(bytes),
    image: image_asset_name(name),
  }
}

///|
fn media_path(input : String, name : String) -> String raise {
  require_media_destination(name)
  require_input_kind(input, 2)
  require_input_kind(input + "/public", 2)
  let path = input + "/public/" + name
  require_input_kind(path, 1)
  path
}

///|
pub fn read_media(input : String, name : String) -> MediaItem raise {
  media_path(input, name) |> ignore
  media_item(name, read_public_bytes(input, name))
}
