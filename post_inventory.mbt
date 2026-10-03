///|
pub(all) struct PostProblem {
  source : String
  message : String
  editable : Bool
} derive(ToJson)

///|
pub extend PostProblem with ToJson::{to_json}

///|
pub(all) struct PostInventory {
  posts : Array[PostSummary]
  problems : Array[PostProblem]
} derive(ToJson)

///|
pub extend PostInventory with ToJson::{to_json}

///|
pub fn inspect_posts(input : String) -> PostInventory raise {
  let posts : Array[PostSummary] = []
  let problems : Array[PostProblem] = []
  for name in post_names(input) {
    try {
      if summarize_post(input, name) is Some(post) {
        posts.push(post)
      }
    } catch {
      error => {
        // A repair link promises only that the raw editor can read this source.
        // Its path/type/UTF-8 checks also reject symlinks, FIFOs and directories.
        let editable = try {
          let _ = read_post(input, name)
          true
        } catch {
          _ => false
        }
        problems.push({
          source: "content/" + name,
          message: error.to_string(),
          editable,
        })
      }
    }
  }
  { posts, problems, }
}
