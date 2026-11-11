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
    #|<style>
    #|:root{color-scheme:light;font:15px/1.65 system-ui,sans-serif;color:#1d252d;background:#f5f6f7}
    #|*{box-sizing:border-box}body{margin:0}a{color:#07557f;text-underline-offset:.2em}
    #|a:focus-visible,summary:focus-visible{outline:3px solid #006d9c;outline-offset:4px}
    #|header{background:#15222d;color:white;padding:.7rem max(1rem,calc((100vw - 72rem)/2));display:flex;align-items:center;gap:1.4rem;flex-wrap:wrap}
    #|header a{color:white}header strong{font-size:1.05rem}.skip{position:absolute;left:-100vw}
    #|.skip:focus{left:1rem;top:1rem;z-index:2;padding:.6rem;background:white}
    #|.shell{display:grid;grid-template-columns:10rem minmax(0,1fr);width:min(72rem,100%);margin:auto}
    #|nav{padding:1.5rem 1rem}nav ul{padding:0;list-style:none;margin:0}nav li a{display:block;padding:.35rem 0}
    #|main{background:white;min-width:0;padding:1.6rem 2rem 4rem;border-inline-start:1px solid #c8d0d6}
    #|h1{font-size:1.9rem;margin:0 0 .55rem;line-height:1.2}h2{font-size:1.3rem;margin:0 0 .65rem}
    #|p{max-width:52rem;margin:.5rem 0 1rem}section{border-top:1px solid #c8d0d6;margin-top:1.6rem;padding-top:1.15rem}
    #|.actions{display:flex;gap:.55rem 1rem;align-items:center;flex-wrap:wrap}
    #|.primary{display:inline-block;background:#07557f;color:white;padding:.42rem .8rem;text-decoration:none}
    #|.primary:hover{background:#173c53}.muted,.row-actions{color:#485966}
    #|table{width:100%;border-collapse:collapse;table-layout:fixed}th,td{text-align:left;vertical-align:top;padding:.6rem .5rem;border-bottom:1px solid #d9dee2;overflow-wrap:anywhere}
    #|th:first-child{width:54%}th:nth-child(2){width:21%}thead{background:#f0f2f4}.row-actions{font-weight:400;font-size:.87rem;margin-top:.12rem}.source-name{font-size:.8rem;font-weight:400;color:#485966;margin-top:.25rem}
    #|.media{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,15rem),1fr));padding:0;list-style:none;gap:0 1rem}
    #|.media li{display:flex;align-items:center;gap:.6rem;min-height:3.4rem;border-bottom:1px solid #d9dee2;overflow-wrap:anywhere}
    #|.media img{object-fit:contain;background:#f0f2f4;flex:none}summary{cursor:pointer}
    #|@media(max-width:40rem){.shell{display:block}nav{padding:.65rem 1rem}nav ul{display:flex;flex-wrap:wrap;gap:.05rem .95rem}main{border-inline:0;padding:1.2rem 1rem 3rem}th,td{font-size:.86rem;padding:.45rem .3rem}th:first-child{width:49%}th:nth-child(2){width:24%}}
    #|</style></head><body><a class="skip" href="#main">本文へ移動</a>
    #|<header><strong>MoonPress</strong><a href="index.html">公開サイト</a></header>
    #|<div class="shell"><nav aria-label="サイト管理"><ul><li><a href="#new">新規作成</a></li><li><a href="#posts">投稿</a></li><li><a href="#pages">固定ページ</a></li><li><a href="#quick-edit">一括変更</a></li><li><a href="#media">メディア</a></li><li><a href="#settings">設定・外観</a></li><li><a href="#publish">公開状況</a></li></ul></nav>
    #|<main id="main" tabindex="-1"><h1>サイト管理</h1>
    #|<p>一覧に掲載する公開済みの内容を確認し、GitHubにログインして編集できます。</p>
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
