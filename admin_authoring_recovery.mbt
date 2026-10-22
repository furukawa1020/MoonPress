///|
fn admin_authoring_recovery(input : String) -> String {
  let out = StringBuilder()
  out.write_string(
    "<p>編集の途中で処理が止まったときの、読み取り専用の案内所です。記事・画像・設定の保存済みファイルは変更しません。編集中の本文はここに表示しません。</p>",
  )
  for
    (kind, title) in [
      ("post", "記事"),
      ("media", "画像"),
      ("settings", "サイト設定"),
    ] {
    out.write_string("<section><h2>" + title + "</h2>")
    try {
      if kind == "media" && path_kind(input + "/public") == 0 {
        out.write_string(
          "<p>画像の保管場所はまだありません。残った編集データもありません。</p>",
        )
      } else {
        let stage = inspect_authoring_stage(input, kind)
        out.write_string(
          "<p>場所：<code>" + escape_html(stage.stage) + "</code></p>",
        )
        if stage.digest is Some(digest) {
          out.write_string(
            "<p class=\"notice\">途中の編集データがあります：\{stage.bytes} bytes。保存済みファイルへ自動適用はしません。</p><p>照合用SHA-256：<code>" +
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
            "<p>途中の編集データは見つかりませんでした。</p>",
          )
        }
      }
    } catch {
      error =>
        out.write_string(
          "<p class=\"notice\">確認できません：" +
          escape_html(error.to_string()) +
          "</p><p>元のファイルを保管し、処理が終わってから再確認してください。上限は8 MiBです。不明なファイルを削除しないでください。</p>",
        )
    }
    out.write_string("</section>")
  }
  out.write_string(
    "<p>コマンドの SITE とバックアップ先は自分のパスに置き換え、シェルに合わせて引用してください。バックアップはサイトの外の、存在しない .backup ファイルを指定します。救出は完全なバックアップを書き、同期してから途中のデータを取り除きます。内容が変わっていたら止まります。バックアップは自動で復元されません。確認して必要な部分を編集画面へ戻してください。</p><p>これは既知の3種類の保存用ステージだけの検査です。未保存のブラウザ入力や匿名一時ファイルの復旧はできません。</p><p><a href=\"/authoring-recovery\">もう一度確認する</a> · <a href=\"/recovery\">ビルド出力の復旧</a> · <a href=\"/rooms/write\">かきかきる〜むへ</a></p>",
  )
  admin_page("編集データの案内所", out.to_string()).replace_all(
    old="lang=\"en\"",
    new="lang=\"ja\"",
  )
}
