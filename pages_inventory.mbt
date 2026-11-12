///|
pub(all) struct PagesInventoryRow {
  source : String
  output : String
  title : String
  kind : String
  status : String
  date : String?
  publish_at : String?
  categories : Array[String]
  tags : Array[String]
} derive(ToJson)

///|
pub extend PagesInventoryRow with ToJson::{to_json}

///|
/// Inspect the exact source snapshot. Status describes build eligibility at
/// one instant, since delivery can lag behind an eligible source.
pub fn pages_inventory(input : String) -> Array[PagesInventoryRow] raise {
  let instant = authoring_time()
  let rows = []
  for name in post_names(input) {
    if inspect_post_document(input, name) is Some((document, output)) {
      let status = if document.draft {
        "draft"
      } else if !publication_due(document.publish_at, instant) {
        "scheduled"
      } else if !document.listed {
        "unlisted"
      } else {
        "published"
      }
      rows.push({
        source: "content/" + name,
        output,
        title: document.title,
        kind: document.kind,
        status,
        date: document.date,
        publish_at: document.publish_at,
        categories: document.categories,
        tags: document.tags,
      })
    }
  }
  rows
}
