///|
test "media filters preserve order and references with strict kinds" {
  let assets : Array[MediaUsage] = [
    {
      item: {
        source: "public/a.PDF",
        url: "a.PDF",
        bytes: 3,
        digest: "a",
        image: false,
      },
      posts: [],
    },
    {
      item: {
        source: "public/画像.PNG",
        url: "encoded",
        bytes: 4,
        digest: "b",
        image: true,
      },
      posts: [],
    },
  ]
  assert_eq(filter_media_references(assets, "  pdf  ", "all").length(), 1)
  assert_eq(
    filter_media_references(assets, "画像", "images")[0].item.source,
    "public/画像.PNG",
  )
  assert_eq(
    filter_media_references(assets, "", "attachments")[0].item.source,
    "public/a.PDF",
  )
  assert_eq(filter_media_references(assets, "pdf", "images").length(), 0)
  let all = filter_media_references(assets, "", "all")
  assert_eq(all.length(), 2)
  assert_eq(all[0].item.source, assets[0].item.source)
  assert_eq(all[1].item.source, assets[1].item.source)
  let rejected = try {
    let _ = filter_media_references(assets, "", "bad")
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}
