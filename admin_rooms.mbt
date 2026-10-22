///|
priv enum PublishingRoom {
  Entrance
  Writing
  Preview
  Building
  Departure
}

///|
fn publishing_room(path : String) -> PublishingRoom? {
  match path {
    "/rooms" => Some(Entrance)
    "/rooms/write" => Some(Writing)
    "/rooms/preview" => Some(Preview)
    "/rooms/build" => Some(Building)
    "/rooms/publish" => Some(Departure)
    _ => None
  }
}

///|
fn room_path(room : PublishingRoom) -> String {
  match room {
    Entrance => "/rooms"
    Writing => "/rooms/write"
    Preview => "/rooms/preview"
    Building => "/rooms/build"
    Departure => "/rooms/publish"
  }
}

///|
fn room_title(room : PublishingRoom) -> String {
  match room {
    Entrance => "01 はじまりのおへや"
    Writing => "02 かきかきる〜む"
    Preview => "03 ぷれびゅ〜る〜む"
    Building => "04 こんぱいら〜る〜む"
    Departure => "05 おひろめる〜む"
  }
}

///|
fn room_map(current : PublishingRoom) -> String {
  let out = StringBuilder()
  out.write_string(
    "<nav class=\"room-map\" aria-label=\"出版の地図\"><ol>",
  )
  for room in [Entrance, Writing, Preview, Building, Departure] {
    out.write_string("<li><a href=\"" + room_path(room) + "\"")
    if room_path(room) == room_path(current) {
      out.write_string(" aria-current=\"step\"")
    }
    out.write_string(">" + room_title(room) + "</a></li>")
  }
  out.write_string("</ol></nav>")
  out.to_string()
}

///|
fn room_production_state(
  input : String,
  token : String,
  export_zip : Bool,
) -> String {
  try {
    let report = inspect_release_readiness(input)
    let status = if report.current {
      "<p class=\"notice\">ビルドの状態：保存済みの公開対象と生成物が一致しています。ローカルのビルド準備は完了です。ホストへの公開は未確認です。</p>"
    } else {
      "<p class=\"notice\">ビルドの状態：再ビルドが必要です。書き込み \{report.pending_writes} 件 / 削除 \{report.pending_deletes} 件。変更計画を確認してから進んでください。</p>"
    }
    status +
    (if export_zip {
      admin_export_form(report, token, japanese=true)
    } else {
      ""
    })
  } catch {
    error =>
      "<p class=\"notice\">ビルドの状態を確認できません：" +
      escape_html(error.to_string()) +
      "</p><p>元の記事や出力を修復してから再確認してください。中断したビルドは <a href=\"/recovery\">復旧の案内所</a> へ。状態を確認できるまで公開用ZIPは作成しません。</p>"
  }
}

///|
fn room_preview_state(input : String) -> String {
  try {
    let output = input.trim_end(chars="/").to_owned() + "/.moonpress-preview"
    let review = review_build_plan(input, output, include_drafts=true)
    let summary = review.plan.summary
    if review.previous_manifest_digest is None {
      "<p class=\"notice\">プレビュー：まだ生成していません。下のボタンでつくってください。</p>"
    } else if !review.manifest_changed &&
      summary.written == 0 &&
      summary.deleted == 0 {
      "<p class=\"notice\">プレビュー：保存済みの記事と一致しています。上の Open built preview から開き、見た目を確認してください。未保存の文章は含まれません。</p>"
    } else {
      "<p class=\"notice\">プレビュー：再生成が必要です。書き込み \{summary.written} 件 / 削除 \{summary.deleted} 件。前のプレビューには最新の保存内容が反映されていません。</p>"
    }
  } catch {
    error =>
      "<p class=\"notice\">プレビューを確認できません：" +
      escape_html(error.to_string()) +
      "</p><p>元の記事と生成物を確認してください。<a href=\"/authoring-recovery\">編集データの案内所</a>も利用できます。</p>"
  }
}

///|
fn room_next_step(input : String, inventory : PostInventory) -> String {
  let suggestion = if inventory.problems.length() > 0 {
    "<a href=\"/\">▶ まず、要修復の記事を確認する</a>"
  } else if inventory.posts.is_empty() {
    "<a href=\"/rooms/write\">▶ 最初の下書きをつくる</a>"
  } else {
    try {
      let report = inspect_release_readiness(input)
      if report.current {
        "<a href=\"/rooms/publish\">▶ 最新の公開用ファイルをもちだす</a>"
      } else if report.drafts > 0 {
        "<a href=\"/rooms/preview\">▶ 保存した下書きをプレビューする</a>"
      } else {
        "<a href=\"/rooms/build\">▶ 公開対象の変更計画を確認する</a>"
      }
    } catch {
      _ =>
        "<a href=\"/rooms/build\">▶ ビルドの状態と修復の案内を確認する</a>"
    }
  }
  "<h2>いまのつづきから</h2><p>" +
  suggestion +
  "</p><p>保存済みの状態に合わせた道案内です。下書きを公開するかは自分で選べます。<a href=\"/?state=draft\">下書きを見直す</a> · <a href=\"/rooms/write\">新しく書く</a></p>"
}

///|
fn admin_room(
  input : String,
  token : String,
  room : PublishingRoom,
) -> String raise {
  let inventory = inspect_posts(input)
  let mut drafts = 0
  for post in inventory.posts {
    if post.draft {
      drafts += 1
    }
  }
  let ready = inventory.posts.length() - drafts
  let status = "<p class=\"room-status\">もちもの：公開対象 \{ready} / 下書き \{drafts} / 要修復 \{inventory.problems.length()}<br>保存済みファイルから確認した状態です。訪問回数を達成度にはしません。</p>"
  let (body, back, next) = match room {
    Entrance =>
      (
        "<p>ようこそ、MoonPressのおへやへ。ひとつずつ扉をあけて、あなたのサイトをつくっていこう。</p><p>操作はリンクとフォームだけ。MoonBitのネイティブコンパイラが、保存・検証・差分ビルドを担当します。</p>" +
        room_next_step(input, inventory),
        None,
        Some(Writing),
      )
    Writing =>
      (
        "<p>まずは、すきなことをひとつ書いてみよう。保存した記事と画像は、あなたのPCに残ります。</p><div class=\"room-actions\"><a href=\"/#new-draft\">▶ 新しい下書きをつくる</a><a href=\"/\">▶ 記事をひらく</a><a href=\"/media\">▶ 画像の道具箱をひらく</a></div><p>書けたら保存して、つぎのおへやへ。保存していない文章はプレビューに反映されません。</p>",
        Some(Entrance),
        Some(Preview),
      )
    Preview =>
      (
        "<p>できあがりを見てみよう。保存した下書きもプレビューに含まれます。下のボタンで生成し、上の Open built preview を開いて確認してください。</p>" +
        room_preview_state(input) +
        admin_build_form(token, japanese=true) +
        "<p>よければ <a href=\"/?state=draft\">下書きをひらき</a>、Set ready for build を選びます。下書きのままの記事は公開用ビルドから除外されます。</p>",
        Some(Writing),
        Some(Building),
      )
    Building =>
      (
        "<p>ここで、書いたものをサイトにしていこう。まずは、変わるファイルを確かめます。確認した計画と実際の入力が違えば、MoonBitが書き込みを止めます。</p>" +
        room_production_state(input, token, false) +
        admin_production_plan_form(token, japanese=true) +
        "<p>表示された変更計画を読んで、Build reviewed production files を選んでください。更新のないページは書き換えません。</p>",
        Some(Preview),
        Some(Departure),
      )
    Departure =>
      (
        "<p>できたサイトを、みんなに見てもらおう。生成物が最新なら、下に公開用ZIPの持ち出しボタンが現れます。</p>" +
        room_production_state(input, token, true) +
        "<ol><li>ZIPを展開し、ホストへアップロードするか、設定済みのGitHub Actionsで配信します。</li><li>ホストのデプロイ成功を確認します。</li><li>公開URLを開き、記事・画像・CSSと削除したページを確認します。</li></ol><p class=\"notice\">ホスティング：未確認。この部屋に入っただけでは公開完了になりません。ローカル管理画面はホストの認証情報を持ちません。</p><div class=\"room-actions\"><a href=\"/publish\">▶ 公開先設定と持ち出しの詳細</a><a href=\"https://github.com/furukawa1020/MoonPress/blob/main/docs/deployment.md\">▶ GitHub Pagesへの道順</a></div>",
        Some(Building),
        None,
      )
  }
  let scene = match room {
    Entrance => "entrance"
    Writing => "writing"
    Preview => "preview"
    Building => "building"
    Departure => "departure"
  }
  let vista = "<div class=\"room-window " +
    scene +
    "\" aria-hidden=\"true\"></div>"
  let doors = StringBuilder()
  doors.write_string("<nav class=\"room-doors\" aria-label=\"次の扉\">")
  if back is Some(previous) {
    doors.write_string(
      "<a href=\"" + room_path(previous) + "\">◀ まえのおへやへ</a>",
    )
  }
  if next is Some(following) {
    doors.write_string(
      "<a href=\"" +
      room_path(following) +
      "\">▶ つぎのおへやへ：" +
      room_title(following) +
      "</a>",
    )
  } else {
    doors.write_string("<a href=\"/rooms\">はじまりにもどる</a>")
  }
  doors.write_string("</nav>")
  admin_page(
    room_title(room),
    room_map(room) +
    vista +
    status +
    admin_post_problems(inventory.problems) +
    "<section class=\"room-dialogue\">" +
    body +
    "</section>" +
    doors.to_string(),
  ).replace_all(old="lang=\"en\"", new="lang=\"ja\"")
}
