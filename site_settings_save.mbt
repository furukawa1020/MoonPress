///|
pub(all) struct SaveSiteSettingsReport {
  digest : String
  changed : Bool
  created : Bool
} derive(ToJson)

///|
pub extend SaveSiteSettingsReport with ToJson::{to_json}

///|
fn require_settings_version(
  snapshot : SiteSettingsSnapshot,
  expected : String,
) -> Unit raise {
  if expected != "absent" && !valid_digest(expected) {
    raise InvalidInput(
      "Expected settings version must be absent or a lowercase SHA-256 value",
    )
  }
  if snapshot.digest.unwrap_or("absent") != expected {
    raise InvalidInput(
      "Site settings changed since they were read; reload before saving",
    )
  }
}

///|
fn verify_settings_stage(
  directory : AuthoringDirectory,
  bytes : Bytes,
) -> Unit raise {
  if directory.read(".moonpress-settings-edit") != bytes {
    raise InvalidInput("Staged settings differ from the requested content")
  }
}

///|
pub fn save_site_settings(
  input : String,
  expected : String,
  content : String,
) -> SaveSiteSettingsReport raise {
  let directory = open_authoring_directory(input)
  defer directory_close(directory.fd)
  directory.lock()
  let current = read_settings_at(directory)
  require_settings_version(current, expected)
  parse_site_config(content) |> ignore
  let stage = input + "/.moonpress-settings-edit"
  if directory.kind(".moonpress-settings-edit") != 0 {
    raise InvalidInput(
      "Settings staging path already exists; inspect before retrying: " + stage,
    )
  }
  let digest = digest_text(content)
  if current.exists && content == current.content {
    directory.sync()
    return { digest, changed: false, created: false, }
  }
  let bytes = @utf8.encode(content)
  let file = directory.create(".moonpress-settings-edit")
  let mut prepared = false
  let mut verified = false
  let mut committed = false
  try {
    directory.write(
      file,
      ".moonpress-settings-edit",
      bytes,
      if current.exists {
        Some("site.json")
      } else {
        None
      },
    )
    prepared = true
    verify_settings_stage(directory, bytes)
    verified = true
    require_settings_version(read_settings_at(directory), expected)
    if current.exists {
      directory.publish(".moonpress-settings-edit", "site.json", false)
      committed = true
      directory.sync()
    } else {
      // Hard-link publication is exclusive: an unexpectedly appearing target
      // cannot be overwritten between the absence check and publication.
      directory.publish(".moonpress-settings-edit", "site.json", true)
      committed = true
      directory.sync()
      verify_settings_stage(directory, bytes)
      directory.remove(".moonpress-settings-edit")
    }
  } catch {
    error => {
      if committed {
        raise InvalidInput(
          "Site settings were saved, but staging cleanup failed or durability is unconfirmed; reload and inspect " +
          stage +
          ": \{error}",
        )
      }
      let cleanup = if prepared && !verified {
        "; unverified staging retained: " + stage
      } else {
        try {
          if prepared {
            verify_settings_stage(directory, bytes)
          } else {
            directory.require_file(".moonpress-settings-edit")
          }
          directory.remove(".moonpress-settings-edit")
          ""
        } catch {
          cause => "; cleanup incomplete; inspect " + stage + ": \{cause}"
        }
      }
      raise InvalidInput("Settings save failed: \{error}" + cleanup)
    }
  }
  { digest, changed: true, created: !current.exists, }
}

///|
pub fn save_site_settings_from_file(
  input : String,
  expected : String,
  replacement : String,
) -> SaveSiteSettingsReport raise {
  require_input_kind(replacement, 1)
  save_site_settings(input, expected, read_text(replacement))
}
