///|
priv struct ArticleArchive {
  output : String
  title : String
  members : Array[Page]
  number : Int
  total : Int
  paginated : Bool
}

///|
fn archive_filename(number : Int) -> String {
  if number == 1 {
    "articles.html"
  } else {
    "articles-\{number}.html"
  }
}

///|
fn article_archives(
  pages : Array[Page],
  page_size : Int?,
) -> Array[ArticleArchive] {
  guard page_size is Some(size) else {
    return [
      {
        output: "articles.html",
        title: "Articles",
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
  let result : Array[ArticleArchive] = []
  let mut offset = 0
  for number = 1; number <= total; number = number + 1 {
    let members : Array[Page] = []
    while offset < ordered.length() && members.length() < size {
      members.push(ordered[offset])
      offset += 1
    }
    result.push({
      output: archive_filename(number),
      title: if number == 1 {
        "Articles"
      } else {
        "Articles — page \{number}"
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
  archive : ArticleArchive,
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
fn render_archive(archive : ArticleArchive) -> String {
  let body = render_collection(archive.title, archive.members)
  if !archive.paginated {
    return body
  }
  let nav = StringBuilder()
  nav.write_string("<nav class=\"pagination\" aria-label=\"Article pages\">\n")
  if archive.number > 1 {
    nav.write_string(
      "<a rel=\"prev\" href=\"" +
      archive_filename(archive.number - 1) +
      "\">Previous</a>\n",
    )
  }
  nav.write_string(
    "<span aria-current=\"page\">Page \{archive.number} of \{archive.total}</span>\n",
  )
  if archive.number < archive.total {
    nav.write_string(
      "<a rel=\"next\" href=\"" +
      archive_filename(archive.number + 1) +
      "\">Next</a>\n",
    )
  }
  nav.write_string("</nav>\n")
  body + nav.to_string()
}
