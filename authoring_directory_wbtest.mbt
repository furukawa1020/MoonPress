///|
test "retained authoring descriptors close on repeated failures" {
  guard @env.get_env_var("MOONPRESS_AUTHORING_PROBE") is Some(input) else {
    return
  }
  let operation = @env.get_env_var("MOONPRESS_AUTHORING_OPERATION").unwrap()
  let version = @env.get_env_var("MOONPRESS_AUTHORING_VERSION").unwrap()
  let stage = @env.get_env_var("MOONPRESS_AUTHORING_STAGE").unwrap()
  let before = @fs.read_dir("/proc/self/fd").length()
  for i = 0; i < 32; i = i + 1 {
    let failed = try {
      if operation == "settings-read" {
        read_site_settings(input) |> ignore
      } else if operation == "post-read" {
        read_post(input, "a.md") |> ignore
      } else if operation == "settings" {
        save_site_settings(input, version, "{\"tag_index\":true}\n") |> ignore
      } else if operation == "media" {
        replace_media(input, "a.png", version, b"replacement") |> ignore
      } else {
        save_post(input, "a.md", version, "# Replacement\n") |> ignore
      }
      false
    } catch {
      _ => true
    }
    assert_true(failed)
    // The fixture owns this temporary tree and intentionally leaves stage failures.
    if path_kind(stage) == 1 {
      @fs.remove_file(stage)
    }
  }
  assert_eq(@fs.read_dir("/proc/self/fd").length(), before)
}

///|
test "empty authoring site cannot become root content or public" {
  let version = digest_text("original")
  for operation in ["read", "save", "new", "duplicate", "media", "store"] {
    let message = try {
      if operation == "read" {
        read_post("", "a.md") |> ignore
      } else if operation == "save" {
        save_post("", "a.md", version, "# New") |> ignore
      } else if operation == "new" {
        new_post("", "new", "New") |> ignore
      } else if operation == "duplicate" {
        duplicate_post("", "a.md", version, "new", "New") |> ignore
      } else if operation == "media" {
        replace_media("", "a.png", version, b"new") |> ignore
      } else {
        store_media("", "a.png", b"new") |> ignore
      }
      ""
    } catch {
      error => error.to_string()
    }
    assert_true(message.contains("Site directory must not be empty"))
  }
}
