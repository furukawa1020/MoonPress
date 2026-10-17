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
  let directory = open_authoring_directory(input)
  defer directory_close(directory.fd)
  read_settings_at(directory)
}

///|
fn read_settings_at(
  directory : AuthoringDirectory,
) -> SiteSettingsSnapshot raise {
  let path = directory.path + "/site.json"
  let kind = directory.kind("site.json")
  if kind == 0 {
    return { exists: false, content: "{}\n", digest: None, }
  }
  let bytes = directory.read("site.json")
  {
    exists: true,
    content: decode_text(bytes, path),
    digest: Some(digest_bytes(bytes)),
  }
}
