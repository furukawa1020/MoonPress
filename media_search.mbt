///|
pub fn filter_media_references(
  assets : Array[MediaUsage],
  query : String,
  kind : String,
) -> Array[MediaUsage] raise {
  if kind != "all" && kind != "images" && kind != "attachments" {
    raise InvalidInput("Media filter must be all, images or attachments")
  }
  let query = query.trim().to_owned().to_lower()
  assets.filter(asset => {
    let selected = match kind {
      "images" => asset.item.image
      "attachments" => !asset.item.image
      _ => true
    }
    selected && asset.item.source.to_lower().contains(query)
  })
}
