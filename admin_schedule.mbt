///|
fn admin_schedule_form(
  source : String,
  name : String,
  hidden : String,
) -> String {
  try {
    let document = parse_document(source, name)
    "<form method=\"post\" action=\"/schedule\">" +
    hidden +
    admin_i18n(
      "<p>ほかの編集を先に保存してください。UTC時刻で予約し、未来の記事は本番URL・RSSから除外します。時刻になったら再ビルドと配信が必要です。下書きは下書きのままです。空欄で予約を解除します。</p>",
      "<p>Save other edits first. Publication uses UTC. Future articles are excluded from production, including direct URLs and feeds. A build and deployment at the due time is required; this local editor does not run a scheduler. Drafts remain drafts. Leave blank to remove scheduling.</p>",
    ) +
    "<label>" +
    admin_i18n("公開日時（UTC）", "Publish at (UTC)") +
    "<input name=\"publish_at\" placeholder=\"2026-12-01T09:00:00Z\" value=\"" +
    escape_html(document.publish_at.unwrap_or("")) +
    "\"></label><button>" +
    admin_i18n("予約を保存", "Save schedule") +
    "</button></form>"
  } catch {
    _ => ""
  }
}
