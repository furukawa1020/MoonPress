///|
priv struct PagesAdminConfig {
  repository : String
  directory : String
}

///|
fn pages_admin_segment(value : String) -> Bool {
  !value.is_empty() &&
  value.length() <= 100 &&
  !value.has_prefix(".") &&
  !value.has_suffix(".") &&
  value.all(c => {
    c.is_ascii_alphabetic() ||
    c.is_ascii_digit() ||
    c == '-' ||
    c == '_' ||
    c == '.'
  })
}

///|
fn parse_pages_admin(value : Json?) -> PagesAdminConfig? raise {
  match value {
    None => None
    Some(Object(fields)) => {
      guard fields.length() == 2 &&
        fields.get("repository") is Some(String(repository)) &&
        fields.get("directory") is Some(String(directory)) else {
        raise InvalidInput(
          "site.json: pages_admin needs repository and directory strings",
        )
      }
      let parts = repository.split("/").map(part => part.to_owned()).to_array()
      if parts.length() != 2 ||
        !parts.all(pages_admin_segment) ||
        (
          !directory.is_empty() &&
          !directory
          .split("/")
          .all(part => pages_admin_segment(part.to_owned()))
        ) {
        raise InvalidInput(
          "site.json: invalid pages_admin repository or directory",
        )
      }
      Some({ repository, directory, })
    }
    _ => raise InvalidInput("site.json: pages_admin must be an object")
  }
}

///|
fn pages_admin_source(config : PagesAdminConfig, source : String) -> String {
  let prefix = if config.directory.is_empty() {
    ""
  } else {
    config.directory + "/"
  }
  prefix +
  source
  .split("/")
  .map(part => url_component(part.to_owned()))
  .to_array()
  .join("/")
}

///|
fn pages_admin_link(url : String, label : String) -> String {
  "<a href=\"" + escape_html(url) + "\">" + escape_html(label) + "</a>"
}

///|
fn pages_admin_table(
  pages : Array[Page],
  sources : Map[String, String],
  config : PagesAdminConfig,
  repository : String,
) -> String {
  if pages.is_empty() {
    return "<p>公開済みの項目がありません。<a href=\"#new\">新規作成へ</a></p>"
  }
  let out = StringBuilder()
  out.write_string(
    "<table><thead><tr><th scope=\"col\">タイトル</th><th scope=\"col\">日付</th><th scope=\"col\">カテゴリ・タグ</th></tr></thead><tbody>",
  )
  for page in chronological_pages(pages) {
    let document = page.document
    let source = sources[page.output]
    let path = pages_admin_source(config, source)
    let name = source.split("/").last().unwrap_or("").to_owned()
    let title = document.title
    let terms = document.categories + document.tags
    out.write_string(
      "<tr><th scope=\"row\">" +
      pages_admin_link(url_component(page.output), title) +
      "<div class=\"row-actions\">" +
      pages_admin_link(repository + "/edit/main/" + path, "編集") +
      " · " +
      pages_admin_link(
        repository + "/actions/workflows/pages-edit.yml",
        "クイック編集",
      ) +
      " · " +
      pages_admin_link(repository + "/commits/main/" + path, "履歴") +
      " · " +
      pages_admin_link(url_component(page.output), "表示") +
      " · " +
      pages_admin_link("#trash", "ゴミ箱") +
      " · 公開中</div><div class=\"source-name\">原稿名 <code>" +
      pages_admin_link(repository + "/blob/main/" + path, name) +
      "</code>" +
      "</div></th><td>" +
      (match document.date {
        Some(date) =>
          "<time datetime=\"" +
          escape_html(date) +
          "\">" +
          escape_html(date) +
          "</time>"
        None => "—"
      }) +
      "</td><td>" +
      (if terms.is_empty() { "—" } else { escape_html(terms.join("、")) }) +
      "</td></tr>",
    )
  }
  out.write_string("</tbody></table>")
  out.to_string()
}

///|
fn pages_admin_media(assets : Array[MediaItem]) -> String {
  if assets.is_empty() {
    return "<p>公開アセットはありません。</p>"
  }
  let out = StringBuilder()
  for images in [true, false] {
    let group = assets.filter(item => item.image == images)
    if group.is_empty() {
      continue
    }
    out.write_string(
      (if images {
        "<h3>画像</h3>"
      } else {
        "<h3>その他のファイル</h3>"
      }) +
      "<ul class=\"media\">",
    )
    for item in group {
      let name = item.source[7:].to_owned()
      let raster = raster_preview_mime(name) is Some(_)
      let thumbnail = raster || name.to_lower().has_suffix(".avif")
      out.write_string(
        "<li>" +
        (if thumbnail {
          "<img src=\"" +
          item.url +
          "\" alt=\"\" loading=\"lazy\" width=\"56\" height=\"40\">"
        } else {
          ""
        }) +
        "<div>" +
        pages_admin_link(item.url, name) +
        "<div class=\"source-name\">" +
        item.bytes.to_string() +
        " B</div>" +
        (if raster {
          "<details><summary>差し替え用 SHA-256</summary><code>" +
          escape_html(item.digest) +
          "</code></details>"
        } else {
          ""
        }) +
        "</div></li>",
      )
    }
    out.write_string("</ul>")
  }
  out.to_string()
}

///|
fn pages_admin_terms(
  label : String,
  terms : Array[TagSummary],
  filename : (String) -> String,
) -> String {
  let out = StringBuilder()
  out.write_string("<h3>" + label + "</h3>")
  if terms.is_empty() {
    out.write_string("<p>使用中の項目はありません。</p>")
  } else {
    out.write_string("<ul class=\"classification\">")
    for term in terms {
      out.write_string(
        "<li>" +
        pages_admin_link(filename(term.name), term.name) +
        " <span>(\{term.count} 件)</span></li>",
      )
    }
    out.write_string("</ul>")
  }
  out.to_string()
}

///|
fn pages_admin_taxonomy(pages : Array[Page], repo : String) -> String {
  let categories : Map[String, Int] = Map([])
  let tags : Map[String, Int] = Map([])
  for page in pages {
    if page.document.kind == "post" {
      for name in page.document.categories {
        categories[name] = categories.get(name).unwrap_or(0) + 1
      }
      for name in page.document.tags {
        tags[name] = tags.get(name).unwrap_or(0) + 1
      }
    }
  }
  let categories : Array[TagSummary] = categories
    .to_array()
    .map(pair => { name: pair.0, count: pair.1, })
  let tags : Array[TagSummary] = tags
    .to_array()
    .map(pair => { name: pair.0, count: pair.1, })
  categories.sort_by((a, b) => a.name.compare(b.name))
  tags.sort_by((a, b) => a.name.compare(b.name))
  "<section id=\"taxonomy\"><h2>カテゴリー・タグ</h2><div class=\"actions\">" +
  pages_admin_link(
    repo + "/actions/workflows/pages-taxonomy.yml",
    "カテゴリー・タグを変更",
  ) +
  pages_admin_link("guide.html#mp-分類を管理", "分類の操作ガイド") +
  "</div><p>一覧に掲載する公開投稿で使われている分類と、その投稿数です。</p>" +
  pages_admin_terms("カテゴリー", categories, category_filename) +
  pages_admin_terms("タグ", tags, tag_filename) +
  "</section>"
}

///|
fn render_pages_admin(
  config : PagesAdminConfig,
  pages : Array[Page],
  sources : Map[String, String],
  assets : Array[MediaItem],
) -> String {
  let repo = "https://github.com/" + config.repository
  let new_workflow = repo + "/actions/workflows/pages-draft.yml"
  let edit_workflow = repo + "/actions/workflows/pages-edit.yml"
  let inventory_workflow = repo + "/actions/workflows/pages-inventory.yml"
  let settings = repo + "/edit/main/"
  let posts = pages.filter(page => page.document.kind == "post")
  let fixed = pages.filter(page => page.document.kind == "page")
  let head =
    #|<!doctype html><html lang="ja"><head><meta charset="utf-8">
    #|<meta name="viewport" content="width=device-width, initial-scale=1">
    #|<meta name="robots" content="noindex, nofollow"><title>サイト管理 · MoonPress</title>
    #|<link rel="stylesheet" href="style.css"><style>
    #|.pages-admin{color-scheme:dark;margin:0;background:var(--bg,#080f24);color:var(--ink,#eee7d5);font:15px/1.65 var(--text,system-ui,sans-serif)}
    #|.pages-admin *{box-sizing:border-box}
    #|.pages-admin a{color:var(--link,#b9dddc);text-underline-offset:.2em}
    #|.pages-admin a:hover{color:var(--gold,#f4d39a)}
    #|.pages-admin a:focus-visible,.pages-admin summary:focus-visible{outline:3px solid var(--gold,#f4d39a);outline-offset:4px}
    #|.pages-admin .site-header{display:flex;justify-content:space-between;align-items:center;gap:.5rem 1.5rem;flex-wrap:wrap;width:min(72rem,calc(100% - 2rem));margin:auto;padding:.75rem 0;border-block-end:1px solid var(--bronze,#846545)}
    #|.pages-admin .brand{color:var(--gold,#f4d39a);text-decoration:none;font:1.45rem/1.25 var(--display,system-ui,sans-serif)}
    #|.pages-admin .skip{position:absolute;left:-100vw}
    #|.pages-admin .skip:focus{left:1rem;top:1rem;z-index:2;padding:.6rem;background:var(--bg,#080f24)}
    #|.pages-admin .shell{display:grid;grid-template-columns:10rem minmax(0,1fr);width:min(72rem,calc(100% - 2rem));margin:auto}
    #|.pages-admin .sidebar{display:block;padding:1.25rem .75rem 1.25rem 0}
    #|.pages-admin .sidebar ul{padding:0;list-style:none;margin:0}
    #|.pages-admin .sidebar li a{display:block;padding:.45rem .25rem}
    #|.pages-admin main{background:var(--panel,#101834);min-width:0;width:auto;margin:0;padding:0 2rem 3.5rem;border-inline-start:1px solid var(--line,#455174)}
    #|.pages-admin .admin-intro{padding:1.55rem 2rem;margin-inline:-2rem}
    #|.pages-admin h1,.pages-admin h2{font-family:var(--display,system-ui,sans-serif);font-weight:400;color:var(--gold,#f4d39a)}
    #|.pages-admin h1{font-size:clamp(1.7rem,4vw,2.25rem);margin:0 0 .45rem;line-height:1.25}
    #|.pages-admin h2{font-size:1.25rem;margin:0 0 .65rem}
    #|.pages-admin p{max-width:48rem;margin:.5rem 0 1rem}
    #|.pages-admin .admin-intro p{max-width:33rem;margin:0;text-shadow:1px 1px 0 var(--bg,#080f24)}
    #|.pages-admin section{border-block-start:1px solid var(--line,#455174);margin-top:1.4rem;padding-top:1rem}
    #|.pages-admin section:first-of-type{border:0;margin-top:.5rem}
    #|.pages-admin .actions{display:flex;gap:.55rem 1rem;align-items:center;flex-wrap:wrap}
    #|.pages-admin .primary{display:inline-block;background:var(--gold,#f4d39a);color:var(--bg,#080f24);padding:.48rem .82rem;text-decoration:none;box-shadow:3px 3px 0 var(--bronze,#846545);font-family:var(--display,system-ui,sans-serif)}
    #|.pages-admin .primary:hover{background:var(--ink,#eee7d5);color:var(--bg,#080f24)}
    #|.pages-admin table{width:100%;border-collapse:collapse;table-layout:fixed}
    #|.pages-admin th,.pages-admin td{text-align:left;vertical-align:top;padding:.6rem .5rem;border-bottom:1px solid var(--line,#455174);overflow-wrap:anywhere}
    #|.pages-admin th:first-child{width:54%}.pages-admin th:nth-child(2){width:21%}
    #|.pages-admin thead{background:var(--bg,#080f24);color:var(--gold,#f4d39a)}
    #|.pages-admin .row-actions,.pages-admin .source-name{font-weight:400;color:var(--muted,#b6c1db);margin-top:.18rem}
    #|.pages-admin .row-actions{font-size:.87rem}.pages-admin .source-name{font-size:.8rem}
    #|.pages-admin .media{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,15rem),1fr));padding:0;list-style:none;gap:0 1rem;max-width:none}
    #|.pages-admin .media li{display:flex;align-items:center;gap:.6rem;min-height:3.4rem;margin:0;border-bottom:1px solid var(--line,#455174);overflow-wrap:anywhere}
    #|.pages-admin .media li>div{min-width:0}.pages-admin .media code{overflow-wrap:anywhere}
    #|.pages-admin .media img{object-fit:contain;background:var(--bg,#080f24);flex:none}
    #|.pages-admin summary{cursor:pointer}
    #|.pages-admin .classification{columns:2;column-width:12rem;padding-inline-start:1.35rem}
    #|.pages-admin .classification li{break-inside:avoid;overflow-wrap:anywhere}
    #|@media(max-width:40rem){
    #|  .pages-admin .shell{display:block;width:100%}.pages-admin .sidebar{padding:.5rem 1rem}
    #|  .pages-admin .sidebar ul{display:flex;flex-wrap:wrap;gap:.05rem .85rem}
    #|  .pages-admin main{border-inline:0;padding:0 1rem 3rem}.pages-admin .admin-intro{padding:1.05rem 1rem;margin-inline:-1rem}
    #|  .pages-admin th,.pages-admin td{font-size:.86rem;padding:.45rem .3rem}
    #|  .pages-admin th:first-child{width:49%}.pages-admin th:nth-child(2){width:24%}
    #|}
    #|</style></head><body class="pages-admin"><a class="skip" href="#main">本文へ移動</a>
    #|<header class="site-header"><a class="brand" href="index.html"><span class="brand-moon" aria-hidden="true"></span>MoonPress</a><a href="index.html">公開サイト</a></header>
    #|<div class="shell"><nav class="sidebar" aria-label="サイト管理"><ul><li><a href="#new">新規作成</a></li><li><a href="#inventory">投稿一覧</a></li><li><a href="#posts">投稿</a></li><li><a href="#pages">固定ページ</a></li><li><a href="#quick-edit">一括変更</a></li><li><a href="#schedule">予約公開</a></li><li><a href="#trash">ゴミ箱</a></li><li><a href="#taxonomy">分類</a></li><li><a href="#media">メディア</a></li><li><a href="#settings">設定・外観</a></li><li><a href="#publish">公開状況</a></li></ul></nav>
    #|<main id="main" tabindex="-1"><div class="admin-intro"><h1>サイト管理</h1>
    #|<p>一覧に掲載する公開済みの内容を確認し、GitHubにログインして編集できます。</p></div>
  head +
  "<section id=\"new\"><h2>新規作成</h2><div class=\"actions\"><a class=\"primary\" href=\"" +
  new_workflow +
  "\">投稿・固定ページを作る</a>" +
  pages_admin_link(repo + "/pulls", "編集中のPRを開く") +
  " · " +
  pages_admin_link(
    repo + "/tree/main/" + pages_admin_source(config, "content"),
    "すべての原稿を開く",
  ) +
  "</div><p>GitHubの「Run workflow」で本文・画像・分類を入力できます。下書きなら編集へ、公開候補なら実行結果からPRへ進みます。</p>" +
  "<details><summary>下書きから公開する手順</summary><ol><li>作成結果の「編集を開く」から本文を入力します。</li><li>GitHubのPreviewで本文を確認します。公開する版では <code>draft</code> を <code>false</code> にして保存します。</li><li>実行結果のPRリンクを開き、公開差分を確認してマージします。</li></ol><p>公開リポジトリのブランチやPRは閲覧できます。機密の下書きは公開リポジトリに保存しないでください。</p></details></section>" +
  "<section id=\"inventory\"><h2>投稿一覧</h2><div class=\"actions\"><a class=\"primary\" href=\"" +
  inventory_workflow +
  "\">投稿・固定ページを検索</a>" +
  pages_admin_link("guide.html#mp-投稿一覧を検索", "一覧の使い方") +
  "</div><p>GitHubの「Run workflow」でタイトル、分類、公開状態を絞り込み、実行結果から編集や履歴を開きます。</p><p>このリポジトリのサマリーは公開されます。下書き・予約・一覧非掲載の情報を含めるときは、共有する内容を確認してください。</p></section>" +
  "<section id=\"posts\"><h2>投稿</h2>" +
  pages_admin_table(posts, sources, config, repo) +
  "</section><section id=\"pages\"><h2>固定ページ</h2>" +
  pages_admin_table(fixed, sources, config, repo) +
  "</section><section id=\"quick-edit\"><h2>クイック編集・一括変更</h2><p>一覧の原稿名をコピーし、GitHubで「Run workflow」を開きます。複数の原稿名をカンマで区切ると、同じ設定を最大20件に適用できます。</p>" +
  pages_admin_link(
    edit_workflow, "編集・複製・復元フォームを開く",
  ) +
  "<details><summary>入力と公開の手順</summary><ol><li>空欄は現状のままです。抜粋などを消すときは消去欄に項目名を指定します。</li><li>複製するときは新しいタイトルとURL名を入力します。復元するときは一覧の「履歴」から戻したいコミットのSHAをコピーします。</li><li>実行結果のSummaryからPRを作成し、公開差分を確認してマージします。</li></ol><p>一覧非掲載でもURLを知っている人は閲覧できます。</p></details>" +
  "</section><section id=\"schedule\"><h2>予約公開</h2><div class=\"actions\">" +
  pages_admin_link(new_workflow, "投稿・固定ページを予約") +
  pages_admin_link(edit_workflow, "予約を変更・解除") +
  "</div><p>日本時間で入力し、PRをマージすると予約が有効になります。公開ジョブが30分ごとに確認します。配信には時間がかかる場合があります。</p>" +
  "</section><section id=\"trash\"><h2>ゴミ箱</h2><div class=\"actions\">" +
  pages_admin_link(
    repo + "/tree/main/" + pages_admin_source(config, "trash"),
    "ゴミ箱の原稿を見る",
  ) +
  pages_admin_link(edit_workflow, "移動・下書き復元フォーム") +
  "</div><p>原稿名をコピーし、GitHubで <code>trash</code>（移動）または <code>untrash</code>（下書き復元）を選びます。確認欄を選んで実行し、PRの公開差分を確認してからマージします。</p></section>" +
  pages_admin_taxonomy(pages, repo) +
  "<section id=\"media\"><h2>メディア</h2><div class=\"actions\">" +
  pages_admin_link(
    repo + "/upload/main/" + pages_admin_source(config, "public"),
    "画像・ファイルを追加",
  ) +
  pages_admin_link(
    repo + "/upload/main/" + pages_admin_source(config, "media-inbox"),
    "差し替え候補をアップロード",
  ) +
  pages_admin_link(
    repo + "/actions/workflows/pages-media.yml",
    "画像を差し替える",
  ) +
  "</div><p>候補を新しいブランチへアップロードし、対象画像のファイル名と SHA-256 を使って差し替えます。</p>" +
  pages_admin_media(assets) +
  "</section><section id=\"settings\"><h2>設定・外観</h2><div class=\"actions\">" +
  pages_admin_link(
    settings + pages_admin_source(config, "site.json"),
    "サイト設定",
  ) +
  pages_admin_link(settings + pages_admin_source(config, "style.css"), "CSS") +
  pages_admin_link(
    settings + pages_admin_source(config, "layout.html"),
    "レイアウト",
  ) +
  "</div></section><section id=\"publish\"><h2>公開状況</h2><div class=\"actions\">" +
  pages_admin_link(
    repo + "/actions/workflows/pages.yml",
    "Pages公開の結果",
  ) +
  pages_admin_link(
    repo + "/actions/workflows/pages-review.yml",
    "PRの公開差分と記事プレビュー",
  ) +
  pages_admin_link(repo + "/commits/gh-pages/", "公開版の履歴") +
  "</div><p>PRをマージするとPagesのビルドが始まります。公開の結果を開き、成功したら公開サイトを確認してください。</p></section></main></div></body></html>\n"
}
