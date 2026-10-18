///|
pub(all) struct MediaRemovalPlan {
  schema : Int
  review_id : String
  item : MediaItem
  references : Array[ReferenceEdge]
  blocked : Bool
  scope : String
} derive(ToJson)

///|
pub extend MediaRemovalPlan with ToJson::{to_json}

///|
fn require_current_media_directory(
  input : String,
  directory : AuthoringDirectory,
) -> Unit raise {
  let current = open_authoring_subdirectory(input, "public")
  defer directory_close(current.fd)
  if directory_same(directory.fd, current.fd) != 1 {
    raise InvalidInput("Media directory changed; inspect removal again")
  }
}

///|
fn media_removal_plan(
  input : String,
  name : String,
  directory : AuthoringDirectory,
) -> MediaRemovalPlan raise {
  require_media_destination(name)
  let item = media_item(name, directory.read(name))
  let plan = plan_site(input, Map([]), None, include_drafts=true)
  let matching = plan.pending.filter(entry => {
    entry.artifact.name == name && entry.artifact.digest == item.digest
  })
  if matching.length() != 1 {
    raise InvalidInput("Media changed during inspection; inspect removal again")
  }
  require_current_media_directory(input, directory)
  let references = sorted_reference_edges(
    plan.references.filter(edge => edge.target == name),
  )
  let identity : Json = [
    "moonpress-media-removal-1",
    input.to_json(),
    name.to_json(),
    item.digest.to_json(),
    plan.manifest.to_json(),
  ]
  {
    schema: 1,
    review_id: digest_text(identity.stringify()),
    item,
    references,
    blocked: !references.is_empty(),
    scope: reference_scope() +
    " Includes drafts. Removal is permanent with no undo. Review CSS, unsupported HTML and external consumers yourself; no automatic build or deployment.",
  }
}

///|
pub fn inspect_media_removal(
  input : String,
  name : String,
) -> MediaRemovalPlan raise {
  require_media_destination(name)
  let directory = open_authoring_subdirectory(input, "public")
  defer directory_close(directory.fd)
  media_removal_plan(input, name, directory)
}
