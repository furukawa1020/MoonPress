///|
priv struct CollectionArchive {
  stem : String
  label : String
  output : String
  title : String
  members : Array[Page]
  number : Int
  total : Int
  paginated : Bool
}

///|
fn archive_filename(number : Int, stem? : String = "articles") -> String {
  if number == 1 {
    stem + ".html"
  } else {
    stem + "-\{number}.html"
  }
}

///|
fn article_archives(
  pages : Array[Page],
  page_size : Int?,
) -> Array[CollectionArchive] {
  collection_archives(pages, page_size, "articles", "Articles", "Article pages")
}

///|
fn tag_archives(
  pages : Array[Page],
  page_size : Int?,
  tag : String,
) -> Array[CollectionArchive] {
  let filename = tag_filename(tag)
  collection_archives(
    pages,
    page_size,
    filename[:filename.length() - 5].to_owned(),
    tag,
    "Tag pages",
  )
}

///|
fn collection_archives(
  pages : Array[Page],
  page_size : Int?,
  stem : String,
  title : String,
  label : String,
) -> Array[CollectionArchive] {
  guard page_size is Some(size) else {
    return [
      {
        stem,
        label,
        output: stem + ".html",
        title,
        members: pages,
        number: 1,
        total: 1,
        paginated: false,
      },
    ]
  }
  let ordered = chronological_pages(pages)
  let total = if ordered.is_empty() {
    1
  } else {
    (ordered.length() - 1) / size + 1
  }
  let result : Array[CollectionArchive] = []
  let mut offset = 0
  for number = 1; number <= total; number = number + 1 {
    let members : Array[Page] = []
    while offset < ordered.length() && members.length() < size {
      members.push(ordered[offset])
      offset += 1
    }
    result.push({
      stem,
      label,
      output: archive_filename(number, stem~),
      title: if number == 1 {
        title
      } else {
        title + " — page \{number}"
      },
      members,
      number,
      total,
      paginated: true,
    })
  }
  result
}

///|
fn archive_dependencies(
  archive : CollectionArchive,
  layout_digest : String,
) -> Array[Dependency] {
  let deps = collection_dependencies(archive.members, layout_digest)
  if archive.paginated {
    deps.push({
      name: "pagination-renderer",
      digest: digest_text("pagination-v1"),
    })
    deps.push({
      name: "pagination",
      digest: digest_text([archive.number, archive.total].to_json().stringify()),
    })
  }
  deps
}

///|
fn render_archive(archive : CollectionArchive) -> String {
  let body = render_collection(archive.title, archive.members)
  if !archive.paginated {
    return body
  }
  let nav = StringBuilder()
  nav.write_string(
    "<nav class=\"pagination\" aria-label=\"" +
    escape_html(archive.label) +
    "\">\n",
  )
  if archive.number > 1 {
    nav.write_string(
      "<a rel=\"prev\" href=\"" +
      archive_filename(archive.number - 1, stem=archive.stem) +
      "\">Previous</a>\n",
    )
  }
  nav.write_string(
    "<span aria-current=\"page\">Page \{archive.number} of \{archive.total}</span>\n",
  )
  if archive.number < archive.total {
    nav.write_string(
      "<a rel=\"next\" href=\"" +
      archive_filename(archive.number + 1, stem=archive.stem) +
      "\">Next</a>\n",
    )
  }
  nav.write_string("</nav>\n")
  body + nav.to_string()
}
