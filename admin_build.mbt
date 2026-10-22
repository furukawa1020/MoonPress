///|
fn admin_build_form(token : String, japanese? : Bool = false) -> String {
  if japanese {
    return "<h2><!--mp:ja-->保存した記事をプレビューにする<!--mp:en-->Preview saved articles<!--mp:end--></h2><form method=\"post\" action=\"/build-preview\">" +
      admin_hidden("token", token) +
      "<p><!--mp:ja-->下書きも含め、保存済みの記事・画像・テーマからプレビューを生成します。未保存の文章は含まれません。公開はしません。<!--mp:en-->Compile saved articles, images and theme, including drafts. Unsaved edits are excluded. This does not publish the site.<!--mp:end--></p><button><!--mp:ja-->プレビューをつくる<!--mp:en-->Create preview<!--mp:end--></button></form>"
  }
  "<h2><!--mp:ja-->サイト全体のプレビュー<!--mp:en-->Full-site preview files<!--mp:end--></h2><form method=\"post\" action=\"/build-preview\">" +
  admin_hidden("token", token) +
  "<p>Compile saved articles, including drafts, with the site theme and assets into <code>.moonpress-preview</code> inside this site. This writes local preview files only. Unsaved editor text is excluded; nothing is deployed.</p><button><!--mp:ja-->プレビューをつくる<!--mp:en-->Build full preview files<!--mp:end--></button></form>"
}

///|
fn admin_build_preview(input : String, token : String) -> String raise {
  let output = input.trim_end(chars="/").to_owned() + "/.moonpress-preview"
  let report = compile_site(input, output, include_drafts=true)
  admin_page(
    "Full preview files built",
    "<p><a href=\"/rooms/preview\"><!--mp:ja-->◀ ぷれびゅ〜る〜むへ<!--mp:en-->◀ Back to the preview room<!--mp:end--></a> · <a href=\"/rooms/build\"><!--mp:ja-->▶ こんぱいら〜る〜むへ進む<!--mp:en-->▶ Enter the compiler room<!--mp:end--></a></p>" +
    "<p>Built from saved sources, including drafts. No deployment performed.</p><p>Pages: \{report.pages}; written: \{report.written}; unchanged: \{report.skipped}; deleted: \{report.deleted}.</p><p>Choose Open built preview in the navigation to view the site with images and links. Generated files are in <code>" +
    escape_html(output) +
    "</code>. This directory can contain private draft content; do not publish it as your production site. Generated project HTML is not served on the administration origin.</p>" +
    admin_build_form(token),
  )
}
