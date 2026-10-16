///|
pub(all) struct SiteSettingsSnapshot {
  exists : Bool
  content : String
  digest : String?
} derive(ToJson)

///|
pub extend SiteSettingsSnapshot with ToJson::{to_json}

///|
pub fn read_site_settings(input : String) -> SiteSettingsSnapshot raise {
  require_input_kind(input, 2)
  require_real_site_directory(input)
  let path = input + "/site.json"
  let kind = path_kind(path)
  if kind == 0 {
    return { exists: false, content: "{}\n", digest: None, }
  }
  require_input_kind(path, 1)
  let bytes = read_site_file_bytes(input, "site.json")
  {
    exists: true,
    content: decode_text(bytes, path),
    digest: Some(digest_bytes(bytes)),
  }
}
