///|
fn admin_authoring_recovery(input : String) -> String {
  let out = StringBuilder()
  out.write_string(
    "<p><!--mp:ja-->編集の途中で処理が止まったときの、読み取り専用の案内所です。記事・画像・設定の保存済みファイルは変更しません。編集中の本文はここに表示しません。<!--mp:en-->Read-only inspection for interrupted saves. Saved articles, images and settings are not changed. Staged body contents are not displayed here.<!--mp:end--></p>",
  )
  for
    (kind, title) in [
      ("post", "<!--mp:ja-->記事<!--mp:en-->Articles<!--mp:end-->"),
      ("media", "<!--mp:ja-->画像<!--mp:en-->Images<!--mp:end-->"),
      (
        "settings", "<!--mp:ja-->サイト設定<!--mp:en-->Site settings<!--mp:end-->",
      ),
    ] {
    out.write_string("<section><h2>" + title + "</h2>")
    try {
      if kind == "media" && path_kind(input + "/public") == 0 {
        out.write_string(
          "<p><!--mp:ja-->画像の保管場所はまだありません。残った編集データもありません。<!--mp:en-->Media storage has not been created. No media stage is present.<!--mp:end--></p>",
        )
      } else {
        let stage = inspect_authoring_stage(input, kind)
        out.write_string(
          "<p><!--mp:ja-->場所：<!--mp:en-->Path: <!--mp:end--><code>" +
          escape_html(stage.stage) +
          "</code></p>",
        )
        if stage.digest is Some(digest) {
          out.write_string(
            "<p class=\"notice\"><!--mp:ja-->途中の編集データがあります：\{stage.bytes} bytes。保存済みファイルへ自動適用はしません。<!--mp:en-->Interrupted editing data: \{stage.bytes} bytes. It will not be applied to saved files automatically.<!--mp:end--></p><p><!--mp:ja-->照合用SHA-256：<!--mp:en-->SHA-256: <!--mp:end--><code>" +
            digest +
            "</code></p><pre>moonpress authoring-stage SITE " +
            kind +
            " --json\nmoonpress authoring-rescue SITE " +
            kind +
            " " +
            digest +
            " /path/outside-site/rescued-" +
            kind +
            ".backup --json</pre>",
          )
        } else {
          out.write_string(
            "<p><!--mp:ja-->途中の編集データは見つかりませんでした。<!--mp:en-->No interrupted editing stage was found.<!--mp:end--></p>",
          )
        }
      }
    } catch {
      error =>
        out.write_string(
          "<p class=\"notice\"><!--mp:ja-->確認できません：<!--mp:en-->Cannot inspect: <!--mp:end-->" +
          escape_html(error.to_string()) +
          "</p><p><!--mp:ja-->元のファイルを保管し、処理が終わってから再確認してください。上限は8 MiBです。不明なファイルを削除しないでください。<!--mp:en-->Preserve the original files and inspect again when other operations finish. The limit is 8 MiB. Do not delete unknown files.<!--mp:end--></p>",
        )
    }
    out.write_string("</section>")
  }
  out.write_string(
    "<p><!--mp:ja-->コマンドの SITE とバックアップ先は自分のパスに置き換え、シェルに合わせて引用してください。バックアップはサイトの外の、存在しない .backup ファイルを指定します。救出は完全なバックアップを書き、同期してから途中のデータを取り除きます。内容が変わっていたら止まります。バックアップは自動で復元されません。確認して必要な部分を編集画面へ戻してください。<!--mp:en-->Replace SITE and the backup destination with your own paths, quoted for your shell. Choose a new .backup file outside the site. Rescue writes and synchronizes a complete backup before removing the stage. Changed data stops rescue. Backups are not applied automatically; inspect them and restore needed text manually.<!--mp:end--></p><p><!--mp:ja-->これは既知の3種類の保存用ステージだけの検査です。未保存のブラウザ入力や匿名一時ファイルの復旧はできません。<!--mp:en-->This checks only the three known saving stages. Unsubmitted browser text and anonymous temporary files cannot be rescued.<!--mp:end--></p><p><a href=\"/authoring-recovery\"><!--mp:ja-->もう一度確認する<!--mp:en-->Inspect again<!--mp:end--></a> · <a href=\"/recovery\"><!--mp:ja-->ビルド出力の復旧<!--mp:en-->Generated-output recovery<!--mp:end--></a> · <a href=\"/rooms/write\"><!--mp:ja-->かきかきる〜むへ<!--mp:en-->Back to the writing room<!--mp:end--></a></p>",
  )
  admin_page(
    "編集データの案内所",
    out.to_string(),
    title_en="Source editing recovery",
  ).replace_all(old="lang=\"en\"", new="lang=\"ja\"")
}
