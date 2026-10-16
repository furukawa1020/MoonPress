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
fn verify_settings_stage(input : String, bytes : Bytes) -> Unit raise {
  if read_site_file_bytes(input, ".moonpress-settings-edit") != bytes {
    raise InvalidInput("Staged settings differ from the requested content")
  }
}

///|
pub fn save_site_settings(
  input : String,
  expected : String,
  content : String,
) -> SaveSiteSettingsReport raise {
  require_input_kind(input, 2)
  let path = input + "/site.json"
  let lock = lock_output(path, shared=false)
  defer native_unlock_output(lock)
  let current = read_site_settings(input)
  require_settings_version(current, expected)
  parse_site_config(content) |> ignore
  let stage = input + "/.moonpress-settings-edit"
  if path_kind(stage) != 0 {
    raise InvalidInput(
      "Settings staging path already exists; inspect before retrying: " + stage,
    )
  }
  let digest = digest_text(content)
  if current.exists && content == current.content {
    return { digest, changed: false, created: false, }
  }
  let bytes = @utf8.encode(content)
  let file = open_file(stage, 2)
  let mut prepared = false
  let mut verified = false
  let mut committed = false
  try {
    write_opened_file(
      file,
      stage,
      bytes,
      mode_source=if current.exists { Some(path) } else { None },
    )
    prepared = true
    verify_settings_stage(input, bytes)
    verified = true
    require_settings_version(read_site_settings(input), expected)
    if current.exists {
      replace_staged_file(stage, path)
      committed = true
    } else {
      // Hard-link publication is exclusive: an unexpectedly appearing target
      // cannot be overwritten between the absence check and publication.
      let result = native_link_file(
        @utf8.encode(stage) + b"\x00",
        @utf8.encode(path) + b"\x00",
      )
      if result != 0 {
        raise InvalidInput(
          "Cannot exclusively create site settings (errno \{result})",
        )
      }
      committed = true
      verify_settings_stage(input, bytes)
      @fs.remove_file(stage)
    }
  } catch {
    error => {
      if committed {
        raise InvalidInput(
          "Site settings were saved, but staging cleanup failed; reload and inspect " +
          stage +
          ": \{error}",
        )
      }
      let cleanup = if prepared && !verified {
        "; unverified staging retained: " + stage
      } else {
        try {
          if prepared {
            verify_settings_stage(input, bytes)
          } else {
            require_input_kind(stage, 1)
          }
          @fs.remove_file(stage)
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
