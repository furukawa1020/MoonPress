const asciiSlug = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
const documentSlug = /^[\p{L}\p{N}](?:[\p{L}\p{N}\p{M}-]*[\p{L}\p{N}\p{M}])?$/u;
const tags = new Set(["p", "div", "h2", "h3", "blockquote", "strong", "em", "b", "i", "ul", "ol", "li", "br", "hr", "pre", "a", "img"]);

function escape(value) {
  return String(value).replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;").replaceAll("'", "&#39;");
}

function render(nodes, depth = 0) {
  if (!Array.isArray(nodes) || depth > 32) throw new Error("原稿の書式が複雑すぎます。");
  return nodes.map(node => {
    if (typeof node === "string") return escape(node);
    if (!node || !tags.has(node.tag)) throw new Error("未対応の書式です。");
    if (node.tag === "br" || node.tag === "hr") return "<" + node.tag + ">";
    if (node.tag === "img") {
      const src = new URL(node.src);
      if (src.protocol !== "https:" || src.username || src.password ||
          typeof node.alt !== "string" || node.alt.length > 240) {
        throw new Error("画像URLと代替テキストを確認してください。");
      }
      return '<img src="' + escape(src.href) + '" alt="' + escape(node.alt) + '" referrerpolicy="no-referrer" loading="lazy">';
    }
    if (node.tag === "pre" && !node.children?.every(child => typeof child === "string")) throw new Error("コードにはテキストを入力してください。");
    let attrs = "";
    if (node.tag === "a") {
      const href = new URL(node.href);
      if (href.protocol !== "https:" || href.username || href.password) throw new Error("リンクにはHTTPSのURLを指定してください。");
      attrs = ' href="' + escape(href.href) + '" rel="noreferrer"';
    }
    return "<" + node.tag + attrs + ">" + render(node.children, depth + 1) + "</" + node.tag + ">";
  }).join("");
}

function user(request) {
  const id = request.headers.get("oai-authenticated-user-id");
  const email = request.headers.get("oai-authenticated-user-email");
  return id && email ? id : null;
}

function response(body, status = 200, type = "text/html; charset=utf-8") {
  return new Response(body, {status, headers: {
    "Content-Type": type, "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "same-origin",
    "Content-Security-Policy": "default-src 'none'; style-src 'self'; font-src 'self'; script-src 'self' 'wasm-unsafe-eval'; connect-src 'self'; img-src https:; form-action 'self'; base-uri 'none'; frame-ancestors 'none'",
  }});
}

function json(body, status = 200) {
  return response(JSON.stringify(body), status, "application/json; charset=utf-8");
}

function page(title, body, {project, section, landing = false, publicSite = false, description = "", feed = ""} = {}) {
  const admin = project && section;
  const brand = publicSite && project ? escape(project.title) : "MoonPress";
  const brandURL = publicSite && project ? projectURL(project.slug) : "/";
  const top = '<a class="brand" href="' + brandURL + '"><span class="moon" aria-hidden="true"></span>' + brand + '</a>';
  const nav = admin ? '<a href="' + projectURL(project.slug) + '">サイトを表示 ↗</a>' : '<a href="/admin">サイト管理</a>';
  const shell = admin ? '<div class="admin-shell">' + projectNavigation(project, section) : '';
  return '<!doctype html><html lang="ja"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>' +
    escape(title) + ' · MoonPress</title><link rel="stylesheet" href="/style.css">' +
    (description ? '<meta name="description" content="' + escape(description) + '">' : '') +
    (feed ? '<link rel="alternate" type="application/rss+xml" href="' + escape(feed) + '">' : '') +
    '</head><body class="' +
    (landing ? 'landing' : admin ? 'admin' : 'site') + '">' +
    '<a class="skip" href="#main">本文へ移動</a><header class="topbar">' + top + '<nav aria-label="サイトメニュー">' + nav + '</nav></header>' +
    shell + '<main id="main" tabindex="-1">' + body + '</main>' + (admin ? '</div>' : '') +
    '<footer><a href="/">MoonPress</a><a href="/font-license.txt">フォントライセンス</a></footer></body></html>';
}

function projectNavigation(project, section) {
  const base = adminURL(project.slug);
  const posts = project.slug === "new" ? base + "/posts" : base;
  const items = [["posts", posts, "投稿"], ["pages", base + "/pages", "固定ページ"], ["settings", base + "/settings", "設定"]];
  return '<aside class="project-sidebar"><a class="all-sites" href="/admin">← サイト一覧</a><strong>' +
    escape(project.title) + '</strong><nav aria-label="サイト管理">' + items.map(([key, url, label]) =>
      '<a href="' + url + '"' + (section === key ? ' aria-current="page"' : '') + '>' + label + '</a>'
    ).join("") + '</nav></aside>';
}

function projectURL(slug) { return "/p/" + encodeURIComponent(slug); }
function adminURL(slug) { return "/admin/" + encodeURIComponent(slug); }
function documentURL(project, slug) { return projectURL(project) + "/" + encodeURIComponent(slug); }

function signIn(returnTo) {
  return "/signin-with-chatgpt?return_to=" + encodeURIComponent(returnTo);
}

function go(path) { return new Response(null, {status:303, headers:{location:path}}); }

function missing() { return response(page("ページが見つかりません", "<h1>ページが見つかりません</h1>"), 404); }

async function form(request) {
  if (!request.headers.get("content-type")?.startsWith("application/x-www-form-urlencoded")) throw new Error("入力形式を確認してください。");
  return new URLSearchParams(await boundedBody(request, 3000));
}

async function boundedBody(request, limit) {
  const reader = request.body?.getReader();
  if (!reader) throw new Error("本文がありません。");
  let length = 0;
  const chunks = [];
  for (;;) {
    const {value, done} = await reader.read();
    if (done) break;
    length += value.length;
    if (length > limit) {
      await reader.cancel();
      throw new Error("原稿が長すぎます。");
    }
    chunks.push(value);
  }
  return new Blob(chunks).text();
}

async function own(env, slug, owner) {
  return env.DB.prepare("SELECT slug, title, tagline FROM projects WHERE slug = ? AND owner = ?").bind(slug, owner).first();
}

async function dashboard(env, owner) {
  const {results} = await env.DB.prepare("SELECT slug, title FROM projects WHERE owner = ? ORDER BY created DESC, slug").bind(owner).all();
  return response(page("サイト管理", '<h1>サイト管理</h1><p><a class="button" href="/admin/new">プロジェクトを作る</a></p>' +
    (results.length ? '<ul class="rows">' + results.map(row => '<li><a href="' + adminURL(row.slug) + (row.slug === 'new' ? '/posts' : '') + '">' +
      escape(row.title) + '</a><a href="' + projectURL(row.slug) + '">サイトを表示</a></li>').join("") + "</ul>" :
      "<p>まだプロジェクトがありません。</p>")));
}

function projectForm(message = "", status = 200, {title = "", slug = ""} = {}) {
  return response(page("プロジェクトを作る", '<h1>プロジェクトを作る</h1>' +
    (message ? '<p role="alert">' + escape(message) + '</p>' : '') +
    '<form method="post"><label>サイト名 <input name="title" maxlength="80" value="' + escape(title) + '" required></label>' +
    '<label>URL名 <input name="slug" maxlength="40" required pattern="[a-z0-9]+(-[a-z0-9]+)*" placeholder="my-site" value="' + escape(slug) + '"></label>' +
    '<button>作成する</button></form>'), status);
}

async function createProject(request, env, owner) {
  const fields = await form(request);
  const title = fields.get("title")?.trim() ?? "";
  const slug = fields.get("slug")?.trim() ?? "";
  if (!title || title.length > 80 || !asciiSlug.test(slug) || slug.length > 40 || slug === "new") {
    return projectForm("サイト名と、英小文字・数字のURL名を入力してください。new は予約済みです。", 400, {title, slug});
  }
  const result = await env.DB.prepare(
    "INSERT INTO projects (slug, owner, title) SELECT ?, ?, ? WHERE (SELECT COUNT(*) FROM projects WHERE owner = ?) < 20 ON CONFLICT(slug) DO NOTHING",
  ).bind(slug, owner, title, owner).run();
  if (!result.meta.changes) return projectForm("このURLは使用中か、作成できるサイト数の上限です。", 409, {title, slug});
  return go(adminURL(slug));
}

function listURL(project, kind) {
  const base = adminURL(project.slug);
  return kind === "page" ? base + "/pages" : project.slug === "new" ? base + "/posts" : base;
}

async function manage(env, project, kind, params) {
  const {results} = await env.DB.prepare(
    "SELECT slug,title,published,version,live_version,trashed,modified FROM documents WHERE project=? AND kind=?",
  ).bind(project.slug, kind).all();
  const fixed = kind === "page";
  const base = adminURL(project.slug);
  const section = fixed ? "pages" : "posts";
  const heading = fixed ? "固定ページ" : "投稿";
  const list = listURL(project, kind);
  const newURL = fixed ? base + "/pages/new" : base + "/new";
  const query = (params.get("q") ?? "").trim().slice(0, 120);
  const order = params.get("order") === "title" ? "title" : "updated";
  const matching = results.filter(row => row.title.toLocaleLowerCase().includes(query.toLocaleLowerCase()));
  const active = matching.filter(row => !row.trashed);
  const filters = [["all", "すべて", active], ["published", "公開済み", active.filter(row => row.published)],
    ["draft", "下書き", active.filter(row => !row.published)], ["trash", "ゴミ箱", matching.filter(row => row.trashed)]];
  const current = filters.find(([key]) => key === params.get("status")) ?? filters[0];
  const link = (status, number = 1) => {
    const kept = new URLSearchParams();
    if (status !== "all") kept.set("status", status);
    if (query) kept.set("q", query);
    if (order !== "updated") kept.set("order", order);
    if (number > 1) kept.set("page", String(number));
    return list + (kept.size ? "?" + kept : "");
  };
  const sorted = current[2].sort((a, b) => (order === "title" ? a.title.localeCompare(b.title, "ja") :
    (b.modified ?? "").localeCompare(a.modified ?? "")) || a.slug.localeCompare(b.slug));
  const totalPages = Math.max(1, Math.ceil(sorted.length / 20));
  const position = Math.min(totalPages, Math.max(1, parseInt(params.get("page"), 10) || 1));
  const tabs = '<nav class="filters" aria-label="公開状態">' + filters.map(([key, label, rows]) =>
    '<a href="' + escape(link(key)) + '"' + (key === current[0] ? ' aria-current="page"' : '') +
    '>' + label + ' <span>(' + rows.length + ')</span></a>').join("") + '</nav>';
  const search = '<form class="list-search" action="' + list + '"><input type="hidden" name="status" value="' + current[0] +
    '"><label>タイトル検索 <input type="search" name="q" maxlength="120" value="' + escape(query) +
    '"></label><label>並び順 <select name="order"><option value="updated">更新が新しい順</option><option value="title"' +
    (order === "title" ? ' selected' : '') + '>タイトル順</option></select></label><button>絞り込む</button></form>';
  const pagination = totalPages > 1 ? '<nav class="filters" aria-label="ページ送り">' +
    (position > 1 ? '<a href="' + escape(link(current[0], position - 1)) + '">前へ</a>' : '') +
    '<span>' + position + ' / ' + totalPages + '</span>' +
    (position < totalPages ? '<a href="' + escape(link(current[0], position + 1)) + '">次へ</a>' : '') + '</nav>' : '';
  const table = sorted.length
    ? '<table class="document-list"><thead><tr><th scope="col">タイトル</th><th scope="col">状態</th><th scope="col">操作</th></tr></thead><tbody>' +
      sorted.slice((position - 1) * 20, position * 20).map(row => {
        const editor = base + '/edit/' + encodeURIComponent(row.slug);
        const display = row.published ? '<a href="' + documentURL(project.slug, row.slug) + '">表示 ↗</a>' : '';
        const status = row.trashed ? "ゴミ箱" : row.published ?
          ((row.live_version === null || row.live_version === row.version) ? "公開済み" : "公開済み・更新下書きあり") : "下書き";
        return '<tr><th scope="row">' + (row.trashed ? escape(row.title) : '<a href="' + editor + '">' + escape(row.title) + '</a>') +
          '</th><td>' + status + '</td><td><div class="row-actions">' + display +
          (row.trashed ? actionForm(base, row, [["restore", "下書きに復元"]]) :
            actionForm(base, row, [["duplicate", "複製"], ["trash", "ゴミ箱へ"]])) + '</div></td></tr>';
      }).join("") + '</tbody></table>'
    : '<p class="empty">該当する' + heading + 'はありません。</p>';
  return response(page(heading, '<div class="screen-heading"><h1>' + heading + '</h1><a class="button" href="' + newURL +
    '">' + (fixed ? "固定ページを追加" : "新規投稿") + '</a></div>' + tabs + search + table + pagination, {project, section}));
}

function actionForm(base, row, actions, unpublish = false) {
  const props = unpublish ? ' id="unpublish-form"' + (row.published ? '' : ' hidden') : '';
  return '<form' + props + ' method="post" action="' + base + '/actions"><input type="hidden" name="slug" value="' + escape(row.slug) +
    '"><input type="hidden" name="version" value="' + row.version + '">' +
    actions.map(([value, label]) => '<button name="action" value="' + value + '">' + label + '</button>').join("") + '</form>';
}

async function documentAction(request, env, project) {
  const fields = await form(request);
  const slug = fields.get("slug");
  const version = Number(fields.get("version"));
  const action = fields.get("action");
  if (!slug || !Number.isSafeInteger(version) || version < 1 || !["duplicate", "trash", "restore", "unpublish"].includes(action)) return missing();
  const row = await env.DB.prepare("SELECT slug,title,version,kind,trashed,published FROM documents WHERE project=? AND slug=?")
    .bind(project.slug, slug).first();
  if (!row) return missing();
  const list = listURL(project, row.kind);
  let result;
  if (action === "duplicate") {
    const marker = "-copy-" + crypto.randomUUID().slice(0, 12);
    const copySlug = Array.from(slug).slice(0, 35).join("").replace(/-+$/, "") + marker;
    result = await env.DB.prepare(
      "INSERT INTO documents(project,slug,title,kind,body,excerpt,modified) " +
      "SELECT project,?,?,kind,body,excerpt,CURRENT_TIMESTAMP FROM documents WHERE project=? AND slug=? AND version=? AND trashed IS NULL " +
      "AND (SELECT COUNT(*) FROM documents WHERE project=?) < 500 ON CONFLICT(project,slug) DO NOTHING",
    ).bind(copySlug, Array.from(row.title).slice(0, 100).join("") + "（コピー）", project.slug, slug, version, project.slug).run();
    if (result.meta.changes) return go(adminURL(project.slug) + "/edit/" + encodeURIComponent(copySlug));
  } else {
    const condition = action === "restore" ? "trashed IS NOT NULL" :
      action === "unpublish" ? "trashed IS NULL AND published IS NOT NULL" : "trashed IS NULL";
    const trash = action === "trash" ? "CURRENT_TIMESTAMP" : "NULL";
    result = await env.DB.prepare(
      "UPDATE documents SET trashed=" + trash + ",published=NULL,live_title=NULL,live_kind=NULL,live_body=NULL,live_excerpt=NULL," +
      "live_modified=NULL,live_version=NULL,modified=CURRENT_TIMESTAMP,version=version+1 WHERE project=? AND slug=? AND version=? AND " + condition,
    ).bind(project.slug, slug, version).run();
    if (result.meta.changes) return go(list + (action === "trash" ? "?status=trash" : "?status=draft"));
  }
  return response(page("操作できませんでした", '<h1>操作できませんでした</h1><p>原稿の状態または件数を確認してください。</p><a href="' + list +
    '">一覧へ戻る</a>', {project, section:row.kind === "page" ? "pages" : "posts"}), 409);
}

function settings(project, message = "", status = 200) {
  return response(page("設定", '<h1>一般設定</h1>' +
    (message ? '<p role="status">' + escape(message) + '</p>' : '') +
    '<form method="post"><label>サイト名 <input name="title" required maxlength="80" value="' + escape(project.title) +
    '"></label><label>キャッチフレーズ <input name="tagline" maxlength="160" value="' + escape(project.tagline) +
    '"></label><p>サイトURL <a href="' + projectURL(project.slug) + '">' + projectURL(project.slug) +
    '</a></p><button>変更を保存</button></form>', {project, section:"settings"}), status);
}

async function saveSettings(request, env, project, owner) {
  const fields = await form(request);
  const title = (fields.get("title") ?? "").trim();
  const tagline = (fields.get("tagline") ?? "").trim();
  if (!title || title.length > 80 || tagline.length > 160) return settings({...project, title, tagline}, "サイト名と文字数を確認してください。", 400);
  await env.DB.prepare("UPDATE projects SET title=?,tagline=? WHERE slug=? AND owner=?")
    .bind(title, tagline, project.slug, owner).run();
  return go(adminURL(project.slug) + "/settings?saved=1");
}

function writer(project, row, kind = "post") {
  const record = row ? {...row, body: JSON.parse(row.body)} : {slug:"", title:"", kind, body:[], version:0};
  const data = JSON.stringify({...record, endpoint:adminURL(project.slug) + "/documents"}).replaceAll("<", "\\u003c");
  const section = record.kind === "page" ? "pages" : "posts";
  const heading = row ? "編集" : section === "pages" ? "固定ページを追加" : "新規投稿";
  return response(page(heading, '<h1>' + heading + '</h1><div class="editor-grid"><div class="editor-main">' +
    '<div class="toolbar" aria-label="文字の書式"><button type="button" id="block-editor" aria-pressed="false">ブロックで編集</button><select id="block" aria-label="段落の種類"><option value="p">本文</option><option value="h2">見出し</option><option value="h3">小見出し</option><option value="blockquote">引用</option></select>' +
    '<button type="button" data-format="bold" aria-label="太字"><b>B</b></button><button type="button" data-format="italic" aria-label="斜体"><i>I</i></button>' +
    '<button type="button" data-format="insertUnorderedList">箇条書き</button><button type="button" data-format="insertOrderedList">番号付き</button>' +
    '<button type="button" id="insert-link">リンク</button><button type="button" data-format="insertHorizontalRule">横線</button>' +
    '<button type="button" id="insert-code">コード</button><button type="button" data-format="undo" aria-label="元に戻す">↶</button><button type="button" data-format="redo" aria-label="やり直す">↷</button></div>' +
    '<section class="paper" id="surface"><label class="reader-only" for="title">タイトル</label><input id="title" maxlength="120" placeholder="タイトルを入力">' +
    '<div id="body" contenteditable="true" role="textbox" aria-label="本文" aria-multiline="true"></div></section>' +
    '<section class="paper" id="preview" hidden></section>' +
    '</div><aside class="editor-settings" aria-label="公開設定"><h2>公開設定</h2><label>種類 <select id="kind"><option value="post">投稿</option><option value="page">固定ページ</option></select></label>' +
    '<label>URL名 <input id="slug" maxlength="60" placeholder="省略時はタイトルから作成"></label>' +
    '<label>抜粋 <textarea id="excerpt" rows="3" maxlength="260"></textarea></label>' +
    '<div class="actions"><button type="button" id="preview-button">プレビュー</button><button type="button" id="save">下書きを保存</button>' +
    '<button type="button" id="publish">公開</button></div><p id="status" role="status"></p><p><a id="live" hidden>公開ページを開く</a></p>' +
    actionForm(adminURL(project.slug), record, [["unpublish", "公開を取り下げる"]], true) +
    '</aside></div><dialog id="code-dialog" aria-labelledby="code-label"><form id="code-form" method="dialog">' +
    '<label id="code-label" for="code-text">コードを入力</label><textarea id="code-text" rows="8" required></textarea>' +
    '<div class="actions"><button>挿入</button><button type="button" id="cancel-code">キャンセル</button></div></form></dialog>' +
    '<dialog id="image-dialog" aria-labelledby="image-label"><form id="image-form" method="dialog">' +
    '<h2 id="image-label">画像を追加</h2><label>HTTPS画像URL <input name="src" type="url" required maxlength="2048"></label>' +
    '<label>代替テキスト <input name="alt" maxlength="240"></label>' +
    '<div class="actions"><button>挿入</button><button type="button" id="cancel-image">キャンセル</button></div></form></dialog>' +
    '<script id="record" type="application/json">' + data + '</script><script src="/writer.js" defer></script>', {project, section}));
}

async function saveDocument(request, env, project) {
  let input, body, excerpt;
  try {
    input = JSON.parse(await boundedBody(request, 84000));
    body = render(input.body);
    excerpt = input.excerpt ?? "";
    if (!body.trim() || typeof input.title !== "string" || !input.title.trim() || input.title.length > 120 ||
        typeof excerpt !== "string" || excerpt.length > 260 || !["post","page"].includes(input.kind) ||
        !Number.isSafeInteger(input.version) || input.version < 0 || typeof input.slug !== "string" ||
        !documentSlug.test(input.slug) || input.slug.length > 60 ||
        typeof input.publish !== "boolean") throw new Error("タイトル・URL名・本文を確認してください。");
    excerpt = excerpt.trim();
  } catch (error) {
    return json({error:error.message}, 400);
  }
  const {slug, kind, version, publish} = input;
  const title = input.title.trim();
  const source = JSON.stringify(input.body);
  const live = publish ? [title, kind, body, excerpt] : [null, null, null, null];
  let updated;
  if (version === 0) {
    updated = await env.DB.prepare(
      "INSERT INTO documents(project,slug,title,kind,body,excerpt,live_title,live_kind,live_body,live_excerpt,modified,published,live_modified,live_version) " +
      "SELECT ?,?,?,?,?,?,?,?,?,?,CURRENT_TIMESTAMP,CASE WHEN ? THEN CURRENT_TIMESTAMP END,CASE WHEN ? THEN CURRENT_TIMESTAMP END,CASE WHEN ? THEN 1 END " +
      "WHERE (SELECT COUNT(*) FROM documents WHERE project=?) < 500 ON CONFLICT(project,slug) DO NOTHING",
    ).bind(project.slug, slug, title, kind, source, excerpt, ...live, Number(publish), Number(publish), Number(publish), project.slug).run();
  } else {
    updated = await env.DB.prepare(
      "UPDATE documents SET title=?,kind=?,body=?,excerpt=?,version=version+1,modified=CURRENT_TIMESTAMP,live_title=COALESCE(?,live_title)," +
      "live_kind=COALESCE(?,live_kind),live_body=COALESCE(?,live_body),live_excerpt=COALESCE(?,live_excerpt)," +
      "published=CASE WHEN ? THEN COALESCE(published,CURRENT_TIMESTAMP) ELSE published END," +
      "live_modified=CASE WHEN ? THEN CURRENT_TIMESTAMP ELSE live_modified END," +
      "live_version=CASE WHEN ? THEN version+1 WHEN published IS NOT NULL THEN COALESCE(live_version,0) ELSE NULL END WHERE project=? AND slug=? AND version=? AND trashed IS NULL",
    ).bind(title, kind, source, excerpt, ...live, Number(publish), Number(publish), Number(publish), project.slug, slug, version).run();
  }
  if (!updated.meta.changes) return json({error:"URL名が使用中か、別タブで更新されました。保存した内容を開き直してください。"}, 409);
  return json({version:version + 1, editor:adminURL(project.slug) + "/edit/" + encodeURIComponent(slug),
    url:documentURL(project.slug, slug), published:publish});
}

function xmlText(value) {
  return escape(value.replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\ufffe\uffff]/g, ""));
}

function publicTime(value) {
  return '<time datetime="' + escape(value.replace(" ", "T") + "Z") + '">' + escape(value.slice(0, 10)) + '</time>';
}

function publicSearchText(html) {
  return html.replace(/<[^>]*>/g, " ").replace(/&(amp|lt|gt|quot|#39);/g, (_, key) =>
    ({amp:"&",lt:"<",gt:">",quot:'"', "#39":"'"}[key])).replace(/\s+/g, " ");
}

async function publicPage(env, projectSlug, postSlug, url) {
  const project = await env.DB.prepare("SELECT slug,title,tagline FROM projects WHERE slug=?").bind(projectSlug).first();
  if (!project) return missing();
  const home = projectURL(projectSlug);
  const feed = home + "/rss.xml";
  const layout = {project, publicSite:true, description:project.tagline, feed};
  if (postSlug && postSlug !== "rss.xml") {
    const row = await env.DB.prepare(
      "SELECT live_title,live_body,live_excerpt,published FROM documents WHERE project=? AND slug=? AND published IS NOT NULL",
    ).bind(projectSlug, postSlug).first();
    return row ? response(page(row.live_title, '<p><a href="' + home + '">← ' + escape(project.title) +
      '</a></p><article class="paper"><h1>' + escape(row.live_title) + '</h1><p class="dates">' + publicTime(row.published) +
      '</p>' + row.live_body + '</article>', {...layout, description:row.live_excerpt || project.tagline})) : missing();
  }
  const published = "FROM documents WHERE project=? AND published IS NOT NULL";
  if (postSlug === "rss.xml") {
    const {results} = await env.DB.prepare("SELECT slug,live_title,live_excerpt,published " + published +
      " AND live_kind='post' ORDER BY published DESC,slug LIMIT 30").bind(projectSlug).all();
    const items = results.map(row => {
      const permalink = escape(url.origin + documentURL(projectSlug, row.slug));
      const date = new Date(row.published.replace(" ", "T") + "Z").toUTCString();
      return '<item><title>' + xmlText(row.live_title) + '</title><link>' + permalink + '</link><guid>' + permalink +
        '</guid><description>' + xmlText(row.live_excerpt ?? "") + '</description><pubDate>' + date + '</pubDate></item>';
    }).join("");
    return response('<?xml version="1.0" encoding="utf-8"?><rss version="2.0"><channel><title>' + xmlText(project.title) +
      '</title><link>' + escape(url.origin + home) + '</link><description>' + xmlText(project.tagline || project.title) +
      '</description><language>ja</language>' + items + '</channel></rss>', 200, "application/rss+xml; charset=utf-8");
  }
  const query = (url.searchParams.get("q") ?? "").trim().slice(0, 120);
  const {results} = await env.DB.prepare("SELECT slug,live_title,live_kind,live_excerpt,published" +
    (query ? ",live_body " : " ") + published +
    (query ? " AND live_kind='post'" : "") + " ORDER BY published DESC,slug").bind(projectSlug).all();
  const needle = query.toLocaleLowerCase();
  const matches = query ? results.filter(row =>
    [row.live_title, row.live_excerpt ?? "", publicSearchText(row.live_body)].some(value => value.toLocaleLowerCase().includes(needle))) : results;
  const list = kind => matches.filter(row => row.live_kind === kind).map(row =>
    '<li><div><a href="' + documentURL(projectSlug, row.slug) + '">' + escape(row.live_title) + '</a>' +
    (row.live_excerpt ? '<p class="excerpt">' + escape(row.live_excerpt) + '</p>' : '') +
    '</div>' + publicTime(row.published) + '</li>').join("");
  const fixed = list("page");
  const posts = list("post");
  return response(page(project.title, '<h1>' + escape(project.title) + '</h1>' +
    (project.tagline ? '<p>' + escape(project.tagline) + '</p>' : '') +
    '<form class="list-search" action="' + home + '"><label>投稿を検索 <input type="search" name="q" maxlength="120" value="' +
    escape(query) + '"></label><button>検索</button><a href="' + feed + '">RSS</a></form><h2>' + (query ? "検索結果" : "投稿一覧") + '</h2>' +
    (posts ? '<ul class="rows">' + posts + '</ul>' : '<p>' + (query ? "一致する投稿はありません。" : "公開された投稿はありません。") + '</p>') +
    (fixed ? '<h2>固定ページ</h2><ul class="rows">' + fixed + '</ul>' : ''), layout));
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;
    try {
      if (request.method === "GET" && path === "/") {
        return response(page("MoonPress", '<section class="entry"><div class="entry-copy"><h1>自分のサイトを<br>つくる。</h1><p>見出しや画像などのブロックを組み合わせて、記事や固定ページを公開できます。</p><div class="actions"><a class="button" href="/admin/new">自分のサイトを作る</a><a href="/admin">サイト管理へ</a></div></div><div class="night" aria-hidden="true"><span class="night-moon"></span><span class="sand"></span><span class="palace"></span></div></section>', {landing: true}));
      }
      if (request.method === "GET" && ["/style.css", "/writer.js"].includes(path)) {
        return response(assets[path.slice(1)], 200, path.endsWith(".css") ? "text/css; charset=utf-8" : "text/javascript; charset=utf-8");
      }
      if (request.method === "GET" && path === "/block-engine.wasm") {
        const bytes = Uint8Array.from(atob(assets["block-engine.wasm"]), char => char.charCodeAt(0));
        return response(bytes, 200, "application/wasm");
      }
      if (request.method === "GET" && path === "/dotgothic16.woff") {
        return new Response(Uint8Array.from(atob(assets["dotgothic16.woff"]), char => char.charCodeAt(0)), {
          headers: {"Content-Type": "font/woff", "Cache-Control": "public, max-age=86400", "X-Content-Type-Options": "nosniff"},
        });
      }
      if (request.method === "GET" && path === "/font-license.txt") {
        return response(assets["font-license.txt"], 200, "text/plain; charset=utf-8");
      }
      const segments = path.split("/").slice(1).map(decodeURIComponent);
      if (segments[0] === "p" && request.method === "GET" && (segments.length === 2 || segments.length === 3)) {
        return await publicPage(env, segments[1], segments[2], url);
      }
      if (segments[0] !== "admin") return missing();
      const owner = user(request);
      if (!owner) return request.method === "GET" ? go(signIn(path)) : json({error:"サインインしてください。"}, 401);
      if (request.method === "POST" && request.headers.get("origin") !== url.origin) return json({error:"操作元が無効です。"}, 403);
      if (path === "/admin" && request.method === "GET") return await dashboard(env, owner);
      if (path === "/admin/new") {
        if (request.method === "GET") return projectForm();
        if (request.method === "POST") return await createProject(request, env, owner);
        return missing();
      }
      const project = await own(env, segments[1], owner);
      if (!project) return missing();
      if ((segments.length === 2 || (segments.length === 3 && segments[2] === "posts" && project.slug === "new")) && request.method === "GET") return await manage(env, project, "post", url.searchParams);
      if (segments[2] === "pages" && request.method === "GET") {
        if (segments.length === 3) return await manage(env, project, "page", url.searchParams);
        if (segments.length === 4 && segments[3] === "new") return writer(project, null, "page");
      }
      if (segments[2] === "new" && segments.length === 3 && request.method === "GET") return writer(project);
      if (segments[2] === "settings" && segments.length === 3) {
        if (request.method === "GET") return settings(project, url.searchParams.has("saved") ? "変更を保存しました。" : "");
        if (request.method === "POST") return await saveSettings(request, env, project, owner);
      }
      if (segments[2] === "actions" && segments.length === 3 && request.method === "POST") return await documentAction(request, env, project);
      if (segments[2] === "documents" && segments.length === 3 && request.method === "POST") return await saveDocument(request, env, project);
      if (segments[2] === "edit" && segments.length === 4 && request.method === "GET") {
        const row = await env.DB.prepare("SELECT slug,title,kind,body,excerpt,version,published FROM documents WHERE project=? AND slug=? AND trashed IS NULL")
          .bind(project.slug, segments[3]).first();
        return row ? writer(project, row) : missing();
      }
      return missing();
    } catch {
      return response(page("一時的に利用できません", "<h1>一時的に利用できません</h1><p>時間をおいて開き直してください。</p>"), 503);
    }
  },
};
