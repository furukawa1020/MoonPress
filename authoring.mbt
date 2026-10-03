///|
pub(all) struct PostSummary {
  source : String
  output : String
  title : String
  draft : Bool
  listed : Bool
  date : String?
  tags : Array[String]
} derive(ToJson)

///|
pub extend PostSummary with ToJson::{to_json}

///|
pub(all) struct PostsReport {
  posts : Array[PostSummary]
} derive(ToJson)

///|
pub extend PostsReport with ToJson::{to_json}

///|
fn post_names(input : String) -> Array[String] raise {
  require_input_kind(input, 2)
  require_input_kind(input + "/content", 2)
  let names = @fs.read_dir(input + "/content").to_owned()
  names.sort()
  names
}

///|
fn summarize_post(input : String, name : String) -> PostSummary? raise {
  let source = "content/" + name
  require_input_kind(input + "/" + source, 1)
  if !name.has_suffix(".md") {
    return None
  }
  let stem = name[:name.length() - 3].to_owned()
  let document = parse_document(
    read_text(input + "/" + source),
    stem,
    filename=source,
  )
  let output = document.slug.unwrap_or(stem) + ".html"
  if !safe_output_name(output) {
    raise InvalidInput("Invalid output filename: " + output)
  }
  Some({
    source,
    output,
    title: document.title,
    draft: document.draft,
    listed: document.listed,
    date: document.date,
    tags: document.tags,
  })
}

///|
pub fn list_posts(input : String) -> PostsReport raise {
  let posts : Array[PostSummary] = []
  for name in post_names(input) {
    if summarize_post(input, name) is Some(post) {
      posts.push(post)
    }
  }
  { posts, }
}
