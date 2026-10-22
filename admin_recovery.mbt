///|
fn admin_recovery(input : String) -> (Int, String) {
  let output = admin_production_output(input)
  let location = "<p>Production output: <code>" +
    escape_html(output) +
    "</code>.</p>"
  let guidance = "<p>This is a read-only snapshot. No files were changed. Recovery checks current files again before acting.</p><p>For an interrupted build, use <code>moonpress recovery-plan &lt;output-directory&gt; --json</code> in your terminal, then <code>moonpress recover &lt;output-directory&gt; --json</code> to perform the validated recovery. Replace the placeholder with the production output above, quoted for your shell.</p><p>Keep the original directory intact if inspection refuses it. Missing or incomplete journals cannot be recovered automatically. Do not delete unknown staging files. This does not restore source edits or verify hosting.</p><p><a href=\"/recovery\">Inspect again</a> · <a href=\"/workflow#review\">Review production build</a> · <a href=\"/publish\">Publishing readiness</a></p>"
  try {
    let report = inspect_recovery(output)
    let state = match report.action {
      "absent" =>
        "No production output exists yet. Build it after reviewing your sources."
      "clean" =>
        "No interrupted publication was found. This does not check whether saved sources need a rebuild."
      "rolled_back" => "Recovery would restore the previous output state."
      _ =>
        "Recovery would keep the completed output and finish staging cleanup."
    }
    (
      200,
      admin_page(
        "Production recovery inspection",
        location +
        "<p>" +
        state +
        "</p><p>Prospective file restores: \{report.restored}; removals: \{report.removed}. Counts exclude staging cleanup.</p>" +
        guidance +
        admin_recovery_links(),
      ),
    )
  } catch {
    error =>
      (
        400,
        admin_page(
          "Recovery inspection blocked",
          location +
          "<p class=\"notice\">" +
          escape_html(error.to_string()) +
          "</p>" +
          guidance +
          admin_recovery_links(),
        ),
      )
  }
}

///|
fn admin_recovery_links() -> String {
  "<p><!--mp:ja-->保存途中のデータは <!--mp:en-->For interrupted source saves, use <!--mp:end--><a href=\"/authoring-recovery\"><!--mp:ja-->編集データの案内所<!--mp:en-->source editing recovery<!--mp:end--></a><!--mp:ja-->、生成途中のサイトは <!--mp:en-->; for interrupted generated output, use <!--mp:end--><a href=\"/recovery\"><!--mp:ja-->ビルド出力の復旧<!--mp:en-->Generated-output recovery<!--mp:end--></a><!--mp:ja--> で確認できます。送信した文章が表示されている場合は、再読み込み前にコピーしてください。<!--mp:en-->. Copy any retained submitted text before reloading.<!--mp:end--></p>"
}
