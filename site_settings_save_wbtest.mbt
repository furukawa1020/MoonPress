///|
test "settings version requires explicit absence or exact content digest" {
  let missing : SiteSettingsSnapshot = {
    exists: false,
    content: "{}\n",
    digest: None,
  }
  require_settings_version(missing, "absent")
  for expected in ["", "bad", digest_text("{}\n")] {
    assert_true(
      try {
        require_settings_version(missing, expected)
        false
      } catch {
        _ => true
      },
    )
  }
  let present : SiteSettingsSnapshot = {
    exists: true,
    content: "{}\n",
    digest: Some(digest_text("{}\n")),
  }
  require_settings_version(present, digest_text("{}\n"))
  assert_true(
    try {
      require_settings_version(present, "absent")
      false
    } catch {
      _ => true
    },
  )
}

///|
test "site settings save filesystem probe" {
  guard @env.get_env_var("MOONPRESS_SETTINGS_SAVE_PROBE") is Some(input) else {
    return
  }
  let created = save_site_settings(input, "absent", "{}\n")
  assert_true(created.created && created.changed)
  assert_eq(read_site_settings(input).digest, Some(created.digest))
  let noop = save_site_settings(input, created.digest, "{}\n")
  assert_false(noop.changed || noop.created)
  for
    content in [
      "{broken", "{\"page_size\":0}", "{\"unknown\":1}", "{\"feed\":{}}",
    ] {
    assert_true(
      try {
        save_site_settings(input, created.digest, content) |> ignore
        false
      } catch {
        _ => true
      },
    )
    assert_eq(read_site_settings(input).digest, Some(created.digest))
  }
  let changed = save_site_settings_from_file(
    input,
    created.digest,
    input + "/replacement",
  )
  assert_false(changed.created)
  assert_true(changed.changed)
  assert_eq(read_site_settings(input).content, "{\"tag_index\":true}\n")
  assert_true(
    try {
      save_site_settings(input, created.digest, "{}\n") |> ignore
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      save_site_settings(input, "absent", "{}\n") |> ignore
      false
    } catch {
      _ => true
    },
  )
  assert_eq(path_kind(input + "/.moonpress-settings-edit"), 0)
}
