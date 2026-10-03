///|
pub fn filter_posts(
  posts : Array[PostSummary],
  query : String,
  state : String,
) -> Array[PostSummary] raise {
  if state != "all" &&
    state != "draft" &&
    state != "ready" &&
    state != "unlisted" {
    raise InvalidInput("Post filter must be all, draft, ready or unlisted")
  }
  let query = query.trim().to_owned().to_lower()
  posts.filter(post => {
    let selected = match state {
      "draft" => post.draft
      "ready" => !post.draft
      "unlisted" => !post.listed
      _ => true
    }
    selected &&
    (
      query.is_empty() ||
      post.title.to_lower().contains(query) ||
      post.source.to_lower().contains(query) ||
      post.tags.any(tag => tag.to_lower().contains(query))
    )
  })
}
