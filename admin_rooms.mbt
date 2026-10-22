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
fn room_title_en(room : PublishingRoom) -> String {
  match room {
    Entrance => "01 The beginning room"
    Writing => "02 The writing room"
    Preview => "03 The preview room"
    Building => "04 The compiler room"
    Departure => "05 The sharing room"
  }
}

///|
fn room_map(current : PublishingRoom) -> String {
  let out = StringBuilder()
  out.write_string("<nav class=\"room-map\" aria-label=\"Publishing map\"><ol>")
  for room in [Entrance, Writing, Preview, Building, Departure] {
    out.write_string("<li><a href=\"" + room_path(room) + "\"")
    if room_path(room) == room_path(current) {
      out.write_string(" aria-current=\"step\"")
    }
    out.write_string(
      ">" + admin_i18n(room_title(room), room_title_en(room)) + "</a></li>",
    )
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
      "<p class=\"notice\"><!--mp:ja-->ビルドの状態：保存済みの公開対象と生成物が一致しています。ローカルのビルド準備は完了です。ホストへの公開は未確認です。<!--mp:en-->Build status: production files match saved ready articles. The local build is ready; hosting has not been verified.<!--mp:end--></p>"
    } else {
      "<p class=\"notice\"><!--mp:ja-->ビルドの状態：再ビルドが必要です。書き込み \{report.pending_writes} 件 / 削除 \{report.pending_deletes} 件。変更計画を確認してから進んでください。<!--mp:en-->Build status: rebuild needed. Writes: \{report.pending_writes}; deletions: \{report.pending_deletes}. Review the plan before continuing.<!--mp:end--></p>"
    }
    status +
    (if export_zip {
      admin_export_form(report, token, japanese=true)
    } else {
      ""
    })
  } catch {
    error =>
      "<p class=\"notice\"><!--mp:ja-->ビルドの状態を確認できません：<!--mp:en-->Cannot inspect production build status: <!--mp:end-->" +
      escape_html(error.to_string()) +
      "</p><p><!--mp:ja-->元の記事や出力を修復してから再確認してください。中断したビルドは <!--mp:en-->Repair the reported source or output and check again. For an interrupted build, visit <!--mp:end--><a href=\"/recovery\"><!--mp:ja-->復旧の案内所<!--mp:en-->output recovery<!--mp:end--></a><!--mp:ja--> へ。状態を確認できるまで公開用ZIPは作成しません。<!--mp:en-->. ZIP export stays unavailable until the files can be verified.<!--mp:end--></p>"
  }
}

///|
fn room_preview_state(input : String) -> String {
  let output = input.trim_end(chars="/").to_owned() + "/.moonpress-preview"
  try {
    let review = review_build_plan(input, output, include_drafts=true)
    let summary = review.plan.summary
    if review.previous_manifest_digest is None {
      "<p class=\"notice\"><!--mp:ja-->プレビュー：まだ生成していません。下のボタンでつくってください。<!--mp:en-->Preview: not built yet. Create it using the button below.<!--mp:end--></p>"
    } else if !review.manifest_changed &&
      summary.written == 0 &&
      summary.deleted == 0 {
      "<p class=\"notice\"><!--mp:ja-->プレビュー：保存済みの記事と一致しています。上の「生成したプレビューを開く」 から開き、見た目を確認してください。未保存の文章は含まれません。<!--mp:en-->Preview: matches saved articles. Use Open built preview above to inspect it. Unsaved edits are excluded.<!--mp:end--></p>"
    } else {
      "<p class=\"notice\"><!--mp:ja-->プレビュー：再生成が必要です。書き込み \{summary.written} 件 / 削除 \{summary.deleted} 件。前のプレビューには最新の保存内容が反映されていません。<!--mp:en-->Preview: rebuild needed. Writes: \{summary.written}; deletions: \{summary.deleted}. The previous preview does not reflect your latest saved changes.<!--mp:end--></p>"
    }
  } catch {
    error =>
      "<p class=\"notice\"><!--mp:ja-->プレビューを確認できません：<!--mp:en-->Cannot inspect preview: <!--mp:end-->" +
      escape_html(error.to_string()) +
      "</p><p><!--mp:ja-->元の記事と生成物を確認してください。プレビュー生成が中断した場合は、出力 <!--mp:en-->Check the reported source or output. If preview generation was interrupted, preserve <!--mp:end--><code>" +
      escape_html(output) +
      "</code><!--mp:ja--> を保管して、ターミナルで次の順に検査・復旧してください。<!--mp:en--> and inspect it in your terminal before recovery:<!--mp:end--></p><pre>moonpress recovery-plan PREVIEW_DIRECTORY --json\nmoonpress recover PREVIEW_DIRECTORY --json</pre><p><!--mp:ja-->PREVIEW_DIRECTORY を上の出力パスに置き換え、シェルに合わせて引用してください。検査で拒否されたら元のファイルを削除しないでください。記事の保存自体が中断した場合は <!--mp:en-->Replace PREVIEW_DIRECTORY with the output path above, quoted for your shell. Preserve files if inspection refuses them. For an interrupted article save, use <!--mp:end--><a href=\"/authoring-recovery\"><!--mp:ja-->編集データの案内所<!--mp:en-->source editing recovery<!--mp:end--></a><!--mp:ja--> へ。<!--mp:en-->.<!--mp:end--></p>"
  }
}

///|
fn room_next_step(input : String, inventory : PostInventory) -> String {
  let suggestion = if inventory.problems.length() > 0 {
    "<a href=\"/\"><!--mp:ja-->▶ まず、要修復の記事を確認する<!--mp:en-->▶ First, inspect articles needing repair<!--mp:end--></a>"
  } else if inventory.posts.is_empty() {
    "<a href=\"/rooms/write\"><!--mp:ja-->▶ 最初の下書きをつくる<!--mp:en-->▶ Create your first draft<!--mp:end--></a>"
  } else {
    try {
      let report = inspect_release_readiness(input)
      if report.current {
        "<a href=\"/rooms/publish\"><!--mp:ja-->▶ 最新の公開用ファイルをもちだす<!--mp:en-->▶ Take your current production files with you<!--mp:end--></a>"
      } else if report.drafts > 0 {
        "<a href=\"/rooms/preview\"><!--mp:ja-->▶ 保存した下書きをプレビューする<!--mp:en-->▶ Preview saved drafts<!--mp:end--></a>"
      } else {
        "<a href=\"/rooms/build\"><!--mp:ja-->▶ 公開対象の変更計画を確認する<!--mp:en-->▶ Review production changes<!--mp:end--></a>"
      }
    } catch {
      _ =>
        "<a href=\"/rooms/build\"><!--mp:ja-->▶ ビルドの状態と修復の案内を確認する<!--mp:en-->▶ Inspect build status and recovery guidance<!--mp:end--></a>"
    }
  }
  "<h2><!--mp:ja-->いまのつづきから<!--mp:en-->Pick up where you left off<!--mp:end--></h2><p>" +
  suggestion +
  "</p><p><!--mp:ja-->保存済みの状態に合わせた道案内です。下書きを公開するかは自分で選べます。<!--mp:en-->This suggestion uses saved files. You choose which drafts become public.<!--mp:end--><a href=\"/?state=draft\"><!--mp:ja-->下書きを見直す<!--mp:en-->Review drafts<!--mp:end--></a> · <a href=\"/rooms/write\"><!--mp:ja-->新しく書く<!--mp:en-->Write something new<!--mp:end--></a></p>"
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
  let status = "<p class=\"room-status\"><!--mp:ja-->もちもの：公開対象 \{ready} / 下書き \{drafts} / 要修復 \{inventory.problems.length()}<!--mp:en-->Inventory: ready \{ready} / drafts \{drafts} / needing repair \{inventory.problems.length()}<!--mp:end--><br><!--mp:ja-->保存済みファイルから確認した状態です。訪問回数を達成度にはしません。<!--mp:en-->These counts describe saved files. Visiting a room does not complete a task.<!--mp:end--></p>"
  let (body, back, next) = match room {
    Entrance =>
      (
        "<p><!--mp:ja-->ようこそ、MoonPressのおへやへ。ひとつずつ扉をあけて、あなたのサイトをつくっていこう。<!--mp:en-->Welcome to the MoonPress rooms. Open each door and bring your site to life.<!--mp:end--></p><p><!--mp:ja-->操作はリンクとフォームだけ。MoonBitのネイティブコンパイラが、保存・検証・差分ビルドを担当します。<!--mp:en-->Links and forms are all you need. The native MoonBit compiler saves, validates and incrementally builds your site.<!--mp:end--></p>" +
        room_next_step(input, inventory),
        None,
        Some(Writing),
      )
    Writing =>
      (
        "<p><!--mp:ja-->まずは、すきなことをひとつ書いてみよう。保存した記事と画像は、あなたのPCに残ります。<!--mp:en-->Write about something you like. Saved articles and images stay on your computer.<!--mp:end--></p><div class=\"room-actions\"><a href=\"/#new-draft\"><!--mp:ja-->▶ 新しい下書きをつくる<!--mp:en-->▶ Create a new draft<!--mp:end--></a><a href=\"/\"><!--mp:ja-->▶ 記事をひらく<!--mp:en-->▶ Open an article<!--mp:end--></a><a href=\"/media\"><!--mp:ja-->▶ 画像の道具箱をひらく<!--mp:en-->▶ Open the image toolbox<!--mp:end--></a></div><p><!--mp:ja-->書けたら保存して、つぎのおへやへ。保存していない文章はプレビューに反映されません。<!--mp:en-->Save your writing before entering the next room. Unsaved edits will not appear in previews.<!--mp:end--></p>",
        Some(Entrance),
        Some(Preview),
      )
    Preview =>
      (
        "<p><!--mp:ja-->できあがりを見てみよう。保存した下書きもプレビューに含まれます。下のボタンで生成し、上の「生成したプレビューを開く」 を開いて確認してください。<!--mp:en-->See how your site will look. Saved drafts are included. Create a preview below, then choose Open built preview above.<!--mp:end--></p>" +
        room_preview_state(input) +
        admin_build_form(token, japanese=true) +
        "<p><!--mp:ja-->よければ <!--mp:en-->When you are happy with it, <!--mp:end--><a href=\"/?state=draft\"><!--mp:ja-->下書きをひらき<!--mp:en-->open a draft<!--mp:end--></a><!--mp:ja-->、「公開対象にする」を選びます。下書きのままの記事は公開用ビルドから除外されます。<!--mp:en--> and choose Set ready for build. Draft articles stay out of production builds.<!--mp:end--></p>",
        Some(Writing),
        Some(Building),
      )
    Building =>
      (
        "<p><!--mp:ja-->ここで、書いたものをサイトにしていこう。まずは、変わるファイルを確かめます。確認した計画と実際の入力が違えば、MoonBitが書き込みを止めます。<!--mp:en-->Turn your writing into a site. First, inspect the files that will change. If the reviewed plan no longer matches current input, MoonBit stops the build.<!--mp:end--></p>" +
        room_production_state(input, token, false) +
        admin_production_plan_form(token, japanese=true) +
        "<p><!--mp:ja-->表示された変更計画を読んで、「確認した公開用ファイルを生成」を選んでください。更新のないページは書き換えません。<!--mp:en-->Read the plan, then choose Build production files. Unchanged pages are not rewritten.<!--mp:end--></p>",
        Some(Preview),
        Some(Departure),
      )
    Departure =>
      (
        "<p><!--mp:ja-->できたサイトを、みんなに見てもらおう。生成物が最新なら、下に公開用ZIPの持ち出しボタンが現れます。<!--mp:en-->Get your site ready for the world. If production files are current, the ZIP download appears below.<!--mp:end--></p>" +
        room_production_state(input, token, true) +
        "<ol><li><!--mp:ja-->ZIPを展開し、ホストへアップロードするか、設定済みのGitHub Actionsで配信します。<!--mp:en-->Extract the ZIP and upload the files to your host, or use your configured GitHub Actions workflow.<!--mp:end--></li><li><!--mp:ja-->ホストのデプロイ成功を確認します。<!--mp:en-->Check that your host reports a successful deployment.<!--mp:end--></li><li><!--mp:ja-->公開URLを開き、記事・画像・CSSと削除したページを確認します。<!--mp:en-->Open the public URL and check articles, images, CSS and removed pages.<!--mp:end--></li></ol><p class=\"notice\"><!--mp:ja-->ホスティング：未確認。この部屋に入っただけでは公開完了になりません。ローカル管理画面はホストの認証情報を持ちません。<!--mp:en-->Hosting: unverified. Entering this room does not publish your site. This local editor has no hosting credentials.<!--mp:end--></p><div class=\"room-actions\"><a href=\"/publish\"><!--mp:ja-->▶ 公開先設定と持ち出しの詳細<!--mp:en-->▶ Publishing settings and export details<!--mp:end--></a><a href=\"https://github.com/furukawa1020/MoonPress/blob/main/docs/deployment.md\"><!--mp:ja-->▶ GitHub Pagesへの道順<!--mp:en-->▶ Directions to GitHub Pages<!--mp:end--></a></div>",
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
  doors.write_string("<nav class=\"room-doors\" aria-label=\"Room doors\">")
  if back is Some(previous) {
    doors.write_string(
      "<a href=\"" +
      room_path(previous) +
      "\"><!--mp:ja-->◀ まえのおへやへ<!--mp:en-->◀ Previous room<!--mp:end--></a>",
    )
  }
  if next is Some(following) {
    doors.write_string(
      "<a href=\"" +
      room_path(following) +
      "\"><!--mp:ja-->▶ つぎのおへやへ：<!--mp:en-->▶ Next room: <!--mp:end-->" +
      admin_i18n(room_title(following), room_title_en(following)) +
      "</a>",
    )
  } else {
    doors.write_string(
      "<a href=\"/rooms\"><!--mp:ja-->はじまりにもどる<!--mp:en-->Back to the beginning<!--mp:end--></a>",
    )
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
    title_en=room_title_en(room),
  ).replace_all(old="lang=\"en\"", new="lang=\"ja\"")
}
