///|
fn admin_publish_report(report : ReleaseReadiness) -> String {
  let state = if report.current {
    "<h2>Production files match saved ready sources</h2><p>The local production files passed validation and need no rebuild at the time of this check.</p>"
  } else {
    "<h2>Build needed before publishing</h2><p>Review and build the latest saved ready sources before uploading. Pending writes: \{report.pending_writes}; deletions: \{report.pending_deletes}. Manifest update: \{report.manifest_changed}.</p>"
  }
  let url = match report.base_url {
    Some(url) =>
      "<p>Configured public URL: <code>" +
      escape_html(url) +
      "</code>. This is configuration, not a verified deployment.</p>"
    None =>
      "<p>No public base_url is configured. Ordinary HTML can work without it; configure your real URL before enabling sitemap/RSS. <a href=\"/site-settings\">Edit site settings</a>.</p>"
  }
  state +
  "<p>Saved ready articles: \{report.ready_posts}; excluded drafts: \{report.drafts}; planned public files: \{report.outputs}.</p>" +
  url +
  "<p>Production output: <code>" +
  escape_html(report.output) +
  "</code>.</p><p><a href=\"/workflow#review\">Review and build production files</a> · <a href=\"/workflow#preview\">Preview saved drafts</a> · <a href=\"/publish\">Check again</a></p>" +
  "<h2>Publish through your host</h2><ol><li>Upload the generated production files from the directory above using your host's deployment tool. Preserve relative filenames and include .nojekyll for GitHub Pages. Keep .moonpress.json as local build state; do not publish it.</li><li>Use your host's synchronization/removal procedure so deleted pages disappear too. Never upload .moonpress-preview: it can contain private drafts.</li><li>Open the actual public URL and check the home page, a recent article, CSS, images and removed URLs. Record the host's deployment result.</li></ol><p><a href=\"https://github.com/furukawa1020/MoonPress/blob/main/docs/deployment.md\">GitHub Actions demonstration setup</a></p><p>MoonPress has not uploaded these files or checked hosting status. This page is a read-only local snapshot, not deployment confirmation; unsaved editor changes are excluded.</p>"
}

///|
fn admin_publish(input : String) -> (Int, String) {
  (
    200,
    admin_page(
      "Publish your site",
      admin_publish_report(inspect_release_readiness(input)),
    ),
  ) catch {
    error =>
      (
        400,
        admin_page(
          "Publishing preparation blocked",
          "<p class=\"notice\">" +
          escape_html(error.to_string()) +
          "</p><p>Repair the reported source/output problem, then review and build again. Existing files were not changed.</p><p><a href=\"/\">Edit articles</a> · <a href=\"/site-settings\">Site settings</a> · <a href=\"/workflow#review\">Review production</a> · <a href=\"/publish\">Check again</a></p>",
        ),
      )
  }
}
