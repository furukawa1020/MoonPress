///|
// Advance when Markdown parsing/rendering changes so old page caches refresh.
fn page_renderer_digest() -> String {
  digest_text("moonpress-renderer-v19")
}
