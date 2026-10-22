///|
fn admin_production_output(input : String) -> String {
  input.trim_end(chars="/").to_owned() + "/.moonpress-build"
}

///|
fn admin_production_form(token : String, review_id? : String = "") -> String {
  if review_id.is_empty() {
    return "<p><a href=\"/rooms/build\"><!--mp:ja-->◀ こんぱいら〜る〜む<!--mp:en-->◀ Compiler room<!--mp:end--></a> · <a href=\"/rooms/publish\"><!--mp:ja-->▶ おひろめる〜むへ<!--mp:en-->▶ Enter the sharing room<!--mp:end--></a></p><h2>Production files</h2><p>Inspect production changes first. The inspection page provides the button to build exactly the reviewed plan. <a href=\"/workflow#review\">Review production changes</a>.</p>"
  }
  "<p><a href=\"/rooms/build\"><!--mp:ja-->◀ こんぱいら〜る〜む<!--mp:en-->◀ Compiler room<!--mp:end--></a> · <a href=\"/rooms/publish\"><!--mp:ja-->▶ おひろめる〜むへ<!--mp:en-->▶ Enter the sharing room<!--mp:end--></a></p><h2>Production files</h2><form method=\"post\" action=\"/build-production\">" +
  admin_hidden("token", token) +
  admin_hidden("review_id", review_id) +
  "<p>Build the changes shown above into <code>.moonpress-build</code>. If the plan changes, the build stops and asks you to inspect again. Drafts and unsaved text are excluded. Hosting deployment is a separate step.</p><button><!--mp:ja-->確認した公開用ファイルを生成<!--mp:en-->Build production files<!--mp:end--></button></form>"
}

///|
fn admin_build_production(
  input : String,
  token : String,
  review_id : String,
) -> String raise {
  let output = admin_production_output(input)
  let report = compile_reviewed_site(input, output, review_id)
  admin_page(
    "Production files built",
    "<p>Built saved ready articles; drafts excluded. No deployment performed.</p><p>Pages: \{report.pages}; written: \{report.written}; unchanged: \{report.skipped}; deleted: \{report.deleted}.</p><p>Local output: <code>" +
    escape_html(output) +
    "</code>. Use the documented hosting workflow to deploy these files. A successful build does not record a deployment. <a href=\"/publish\">Check publishing readiness and next steps</a>.</p>" +
    admin_production_form(token),
  )
}

///|
fn admin_production_plan_form(
  token : String,
  japanese? : Bool = false,
) -> String {
  if japanese {
    return "<h2><!--mp:ja-->変わるファイルをたしかめる<!--mp:en-->Inspect changed files<!--mp:end--></h2><form method=\"post\" action=\"/plan-production\">" +
      admin_hidden("token", token) +
      "<p><!--mp:ja-->公開対象の保存済み記事を検証し、追加・更新・削除するファイルを表示します。下書きと未保存の文章は含まれません。この確認ではファイルを書き込みません。<!--mp:en-->Validate saved ready articles and inspect files to add, update or remove. Drafts and unsaved edits are excluded. Inspection writes no files.<!--mp:end--></p><button><!--mp:ja-->変更計画をみる<!--mp:en-->Review changes<!--mp:end--></button></form>"
  }
  "<h2><!--mp:ja-->変更計画をみる<!--mp:en-->Inspect production changes<!--mp:end--></h2><form method=\"post\" action=\"/plan-production\">" +
  admin_hidden("token", token) +
  "<p>Validate saved ready articles and inspect planned changes to <code>.moonpress-build</code>. Drafts and unsaved text are excluded. No files or output directory are created.</p><button><!--mp:ja-->変更計画をみる<!--mp:en-->Inspect production changes<!--mp:end--></button></form>"
}

///|
fn admin_production_changes(report : BuildReport) -> String {
  let out = StringBuilder()
  out.write_string(
    admin_table_start("Planned output changes") +
    "<thead><tr><th>Action</th><th>Path</th><th>Reason</th></tr></thead><tbody>",
  )
  for change in report.changes {
    out.write_string(
      "<tr><td>" +
      escape_html(change.action) +
      "</td><td><code>" +
      escape_html(change.path) +
      "</code></td><td>" +
      escape_html(change.reason) +
      "</td></tr>",
    )
  }
  out.write_string("</tbody></table></div>")
  out.to_string()
}

///|
fn admin_plan_production(input : String, token : String) -> String raise {
  let output = admin_production_output(input)
  let review = review_build_plan(input, output)
  let plan = review.plan
  let report = plan.summary
  admin_page(
    "Production changes inspected",
    "<p>Read-only inspection; drafts excluded. No files written or deployment performed.</p><p>Pages: \{report.pages}; would write: \{report.written}; unchanged: \{report.skipped}; would delete: \{report.deleted}.</p><p>Planned output: <code>" +
    escape_html(output) +
    "</code>. Building checks this reviewed plan again. If it changes, no production files are written; inspect again before continuing.</p>" +
    admin_production_changes(report) +
    "<p>Ownership manifest: " +
    (if review.manifest_changed { "will update" } else { "unchanged" }) +
    ". This metadata file is separate from the output counts.</p><details><summary>Ownership manifest digests</summary><p>Before: " +
    admin_digest(review.previous_manifest_digest) +
    "; after: " +
    admin_digest(Some(review.next_manifest_digest)) +
    "</p></details>" +
    admin_dependency_review(plan) +
    admin_production_plan_form(token) +
    admin_production_form(token, review_id=review.review_id),
  )
}
