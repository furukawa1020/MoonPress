///|
test "image block declared sizes require agreeing figure classes" {
  for
    figure in [
      "<figure>", "<figure class='wp-block-image'>", "<figure class='wp-block-image size-small'>",
    ] {
    let source = "<!-- wp:image {\"sizeSlug\":\"large\"} -->" +
      figure +
      "<img src='x.png'></figure><!-- /wp:image -->"
    let refused = try {
      wxr_body(source) |> ignore
      false
    } catch {
      _ => true
    }
    assert_true(refused)
  }
}
