///|
fn rest_delete(
  input : String,
  path : String,
  query : Map[String, String],
  base : String,
  authorization : String?,
  if_match : String?,
) -> RestResponse raise {
  let target = rest_edit_target(path) catch {
    _ => return rest_error(400, "rest_invalid_param")
  }
  let (kind, id) = match target {
    Some(target) => target
    None => return rest_error(405, "rest_no_route")
  }
  for key, value in query {
    if (key != "force" && key != "context") ||
      (key == "force" && value != "false" && value != "0") ||
      (key == "context" && value != "edit") {
      return rest_error(400, "rest_invalid_param")
    }
  }
  rest_with_access(input, authorization, fn(principal, directory) raise {
    let (name, snapshot, document) = match
      rest_find_post(input, directory, kind, id) {
      Some(found) => found
      None => return rest_error(404, "rest_post_invalid_id")
    }
    if !role_can_delete(
        principal.role,
        principal.id,
        document.author,
        kind,
        !document.draft,
      ) {
      return rest_error(403, "rest_cannot_delete")
    }
    let expected = match if_match {
      Some(value) => value
      None => return rest_error(428, "moonpress_precondition_required")
    }
    if expected.length() != 66 ||
      !expected.has_prefix("\"") ||
      !expected.has_suffix("\"") ||
      !valid_digest(expected[1:65].to_owned()) {
      return rest_error(400, "moonpress_invalid_precondition")
    }
    if expected[1:65].to_owned() != snapshot.digest {
      return rest_error(412, "moonpress_source_changed")
    }
    let value = rest_edit_value(
      document,
      name[:name.length() - 3].to_owned(),
      base,
      snapshot.digest,
    )
    prepare_authoring_vault(input, ".moonpress-trash") |> ignore
    let revision = trash_post_at(input, directory, name, snapshot.digest)
    let fields = match value {
      Object(fields) => fields
      _ => raise InvalidInput("Expected post object")
    }
    fields["status"] = "trash".to_json()
    fields["moonpress_trash_id"] = revision.id.to_json()
    rest_ok(value)
  })
}
