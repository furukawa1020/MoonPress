///|
pub(all) struct RemoveMediaReport {
  item : MediaItem
  review_id : String
} derive(ToJson)

///|
pub extend RemoveMediaReport with ToJson::{to_json}

///|
pub fn remove_media(
  input : String,
  name : String,
  expected_review : String,
  acknowledge_unscanned~ : Bool,
) -> RemoveMediaReport raise {
  if !acknowledge_unscanned {
    raise InvalidInput(
      "Confirm permanent removal and inspect CSS, unsupported HTML and external uses first",
    )
  }
  if !valid_digest(expected_review) {
    raise InvalidInput("Invalid media removal review ID")
  }
  require_media_destination(name)
  let directory = open_authoring_subdirectory(input, "public")
  defer directory_close(directory.fd)
  directory.lock()
  let plan = media_removal_plan(input, name, directory)
  if plan.review_id != expected_review {
    raise InvalidInput("Media removal plan changed; inspect and confirm again")
  }
  if plan.blocked {
    raise InvalidInput(
      "Media is referenced by saved sources, including drafts; remove references first",
    )
  }
  require_current_media_directory(input, directory)
  if digest_bytes(directory.read(name)) != plan.item.digest {
    raise InvalidInput("Media changed; inspect removal again")
  }
  directory.remove(name)
  { item: plan.item, review_id: plan.review_id, }
}
