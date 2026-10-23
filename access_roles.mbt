///|
pub fn role_capabilities(role : String) -> Array[String] raise {
  if !["subscriber", "contributor", "author", "editor", "administrator"].contains(
      role,
    ) {
    raise InvalidInput("Unknown single-site role")
  }
  let capabilities = ["read"]
  if role == "subscriber" {
    return capabilities
  }
  capabilities.append(["edit_posts", "delete_posts"])
  if role == "contributor" {
    return capabilities
  }
  capabilities.append([
    "publish_posts", "upload_files", "edit_published_posts", "delete_published_posts",
  ])
  if role == "author" {
    return capabilities
  }
  capabilities.append([
    "edit_others_posts", "delete_others_posts", "edit_pages", "edit_others_pages",
    "publish_pages", "delete_pages", "edit_published_pages", "delete_published_pages",
    "delete_others_pages", "read_private_posts", "read_private_pages", "manage_categories",
    "moderate_comments",
  ])
  if role == "administrator" {
    capabilities.append([
      "list_users", "create_users", "edit_users", "delete_users", "manage_options",
    ])
  }
  capabilities
}

///|
pub fn role_can_edit(
  role : String,
  user : Int,
  owner : Int,
  kind : String,
  published : Bool,
) -> Bool raise {
  if user <= 0 || owner < 0 || (kind != "post" && kind != "page") {
    return false
  }
  let capabilities = role_capabilities(role)
  let suffix = if kind == "page" { "pages" } else { "posts" }
  capabilities.contains("edit_" + suffix) &&
  (user == owner || capabilities.contains("edit_others_" + suffix)) &&
  (!published || capabilities.contains("edit_published_" + suffix))
}

///|
pub fn role_can_delete(
  role : String,
  user : Int,
  owner : Int,
  kind : String,
  published : Bool,
) -> Bool raise {
  if user <= 0 || owner < 0 || (kind != "post" && kind != "page") {
    return false
  }
  let capabilities = role_capabilities(role)
  let suffix = if kind == "page" { "pages" } else { "posts" }
  capabilities.contains("delete_" + suffix) &&
  (user == owner || capabilities.contains("delete_others_" + suffix)) &&
  (!published || capabilities.contains("delete_published_" + suffix))
}
