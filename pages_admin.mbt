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
fn pages_admin_media(assets : Array[String]) -> String {
  if assets.is_empty() {
    return "<p>公開アセットはありません。</p>"
  }
  let out = StringBuilder()
  out.write_string("<ul class=\"media\">")
  for asset in assets {
    let href = url_component(asset)
    let extension = asset.to_lower()
    let image = [".png", ".jpg", ".jpeg", ".gif", ".webp", ".avif"].any(suffix => {
      extension.has_suffix(suffix)
    })
    out.write_string(
      "<li>" +
      (if image {
        "<img src=\"" +
        href +
        "\" alt=\"\" loading=\"lazy\" width=\"56\" height=\"40\">"
      } else {
        ""
      }) +
      pages_admin_link(href, asset) +
      "</li>",
    )
  }
  out.write_string("</ul>")
  out.to_string()
}

///|
fn render_pages_admin(
  config : PagesAdminConfig,
  pages : Array[Page],
  sources : Map[String, String],
  assets : Array[String],
) -> String {
  let repo = "https://github.com/" + config.repository
  let new_workflow = repo + "/actions/workflows/pages-draft.yml"
  let edit_workflow = repo + "/actions/workflows/pages-edit.yml"
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
    #|.pages-admin .media img{object-fit:contain;background:var(--bg,#080f24);flex:none}
    #|.pages-admin summary{cursor:pointer}
    #|@media(max-width:40rem){
    #|  .pages-admin .shell{display:block;width:100%}.pages-admin .sidebar{padding:.5rem 1rem}
    #|  .pages-admin .sidebar ul{display:flex;flex-wrap:wrap;gap:.05rem .85rem}
    #|  .pages-admin main{border-inline:0;padding:0 1rem 3rem}.pages-admin .admin-intro{padding:1.05rem 1rem;margin-inline:-1rem}
    #|  .pages-admin th,.pages-admin td{font-size:.86rem;padding:.45rem .3rem}
    #|  .pages-admin th:first-child{width:49%}.pages-admin th:nth-child(2){width:24%}
    #|}
    #|</style></head><body class="pages-admin"><a class="skip" href="#main">本文へ移動</a>
    #|<header class="site-header"><a class="brand" href="index.html"><span class="brand-moon" aria-hidden="true"></span>MoonPress</a><a href="index.html">公開サイト</a></header>
    #|<div class="shell"><nav class="sidebar" aria-label="サイト管理"><ul><li><a href="#new">新規作成</a></li><li><a href="#posts">投稿</a></li><li><a href="#pages">固定ページ</a></li><li><a href="#quick-edit">一括変更</a></li><li><a href="#media">メディア</a></li><li><a href="#settings">設定・外観</a></li><li><a href="#publish">公開状況</a></li></ul></nav>
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
  "</div><p>GitHubの「Run workflow」で種類・タイトル・スラッグを選びます。実行結果のリンクから本文を編集します。</p>" +
  "<details><summary>下書きから公開する手順</summary><ol><li>作成結果の「編集を開く」から本文を入力します。</li><li>GitHubのPreviewで本文を確認します。公開する版では <code>draft</code> を <code>false</code> にして保存します。</li><li>実行結果のPRリンクを開き、公開差分を確認してマージします。</li></ol><p>公開リポジトリのブランチやPRは閲覧できます。機密の下書きは公開リポジトリに保存しないでください。</p></details></section>" +
  "<section id=\"posts\"><h2>投稿</h2>" +
  pages_admin_table(posts, sources, config, repo) +
  "</section><section id=\"pages\"><h2>固定ページ</h2>" +
  pages_admin_table(fixed, sources, config, repo) +
  "</section><section id=\"quick-edit\"><h2>クイック編集・一括変更</h2><p>一覧の原稿名をコピーし、GitHubで「Run workflow」を開きます。複数の原稿名をカンマで区切ると、同じ設定を最大20件に適用できます。</p>" +
  pages_admin_link(
    edit_workflow, "編集・複製・復元フォームを開く",
  ) +
  "<details><summary>入力と公開の手順</summary><ol><li>空欄は現状のままです。抜粋などを消すときは消去欄に項目名を指定します。</li><li>複製するときは新しいタイトルとURL名を入力します。復元するときは一覧の「履歴」から戻したいコミットのSHAをコピーします。</li><li>実行結果のSummaryからPRを作成し、公開差分を確認してマージします。</li></ol><p>一覧非掲載でもURLを知っている人は閲覧できます。公開予約は、設定した時刻以降に再公開が必要です。</p></details>" +
  "</section><section id=\"media\"><h2>メディア</h2>" +
  pages_admin_link(
    repo + "/upload/main/" + pages_admin_source(config, "public"),
    "画像・ファイルを追加",
  ) +
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
    "PRの公開差分",
  ) +
  pages_admin_link(repo + "/commits/gh-pages/", "公開版の履歴") +
  "</div><p>PRをマージするとPagesのビルドが始まります。公開の結果を開き、成功したら公開サイトを確認してください。</p></section></main></div></body></html>\n"
}
