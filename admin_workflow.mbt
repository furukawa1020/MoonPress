///|
fn admin_workflow_summary(inventory : PostInventory) -> String {
  let mut drafts = 0
  for post in inventory.posts {
    if post.draft {
      drafts += 1
    }
  }
  let ready = inventory.posts.length() - drafts
  "<p>Saved sources: " +
  ready.to_string() +
  " ready for build; " +
  drafts.to_string() +
  " drafts; " +
  inventory.problems.length().to_string() +
  " needing repair.</p><p>These counts describe source metadata, not successful validation or deployment.</p>"
}

///|
fn admin_workflow(input : String, token : String) -> String raise {
  let inventory = inspect_posts(input)
  admin_page(
    "From draft to published site",
    "<p>Follow these steps using saved articles. Keep this terminal open while writing.</p>" +
    admin_workflow_summary(inventory) +
    admin_post_problems(inventory.problems) +
    "<section id=\"write\"><h2>1. Write and save</h2><p><a href=\"/#new-draft\">Create a draft</a>, or <a href=\"/\">choose an article to edit</a>. Save article before continuing. <a href=\"/media\">Upload images</a> and paste their Markdown snippets into the body.</p></section>" +
    "<section id=\"preview\"><h2>2. Preview your saved drafts</h2><p>Use the full-site preview to see the theme, images and links. After building, choose Open built preview in the navigation. It opens on a separate local port; reload after rebuilding.</p>" +
    admin_build_form(token) +
    "</section>" +
    "<section id=\"ready\"><h2>3. Choose what goes live</h2><p><a href=\"/?state=draft\">Open a draft</a>, save its final text, then choose <strong>Set ready for build</strong>. Ready articles enter normal builds. Drafts stay out; making an article ready does not upload it.</p></section>" +
    "<section id=\"review\"><h2>4. Review before building</h2><p>Inspect which files will be created, kept or removed. Fix any reported source or output problem first.</p>" +
    admin_production_plan_form(token) +
    "</section>" +
    "<section id=\"build\"><h2>5. Create production files</h2>" +
    admin_production_form(token) +
    "</section>" +
    "<section id=\"publish\"><h2>6. Publish and verify</h2><p>Upload only the production output to your host, or commit the saved sources and run your configured GitHub Actions workflow. For GitHub Pages, enable the required Pages setting and check the workflow plus the public URL.</p><p><a href=\"https://github.com/furukawa1020/MoonPress/blob/main/docs/deployment.md\">GitHub Actions setup guide</a></p><p>Hosting status is not connected to this local editor. A local preview or build is not a deployment receipt.</p></section>",
  )
}
