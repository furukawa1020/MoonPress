const $ = (id) => document.getElementById(id);
const editor = $("body");
const title = $("title");
const kind = $("kind");
const slug = $("slug");
const keyPrefix = "moonpress-writer:v1:";
const lastKey = keyPrefix + "current";
const maxBody = 160_000;
const maxShare = 18_000;
const allowed = new Set(["P", "DIV", "H2", "H3", "BLOCKQUOTE", "B", "STRONG",
  "I", "EM", "UL", "OL", "LI", "BR", "A"]);
let id = crypto.randomUUID();
let selection;
let timer;
let dirty = false;
let previewing = false;

function linkURL(value) {
  if (!value || /[\s()<>\\]/u.test(value)) return "";
  try {
    const url = new URL(value);
    return url.protocol === "https:" && !url.username && !url.password ? url.href : "";
  } catch {
    return "";
  }
}

function cleaned(root) {
  const fragment = document.createDocumentFragment();
  function copy(from, to) {
    if (from.nodeType === Node.TEXT_NODE) {
      to.append(document.createTextNode(from.data));
      return;
    }
    if (from.nodeType !== Node.ELEMENT_NODE || ["SCRIPT", "STYLE", "IFRAME", "TEMPLATE"].includes(from.tagName)) return;
    const url = from.tagName === "A" && linkURL(from.getAttribute("href"));
    const tag = from.tagName === "H1" ? "H2" : from.tagName;
    let target = to;
    if (allowed.has(tag) && (tag !== "A" || url)) {
      target = document.createElement(tag);
      if (url) target.href = url;
      to.append(target);
    }
    for (const child of from.childNodes) copy(child, target);
  }
  for (const child of root.childNodes) copy(child, fragment);
  return fragment;
}

function parse(html) {
  const template = document.createElement("template");
  template.innerHTML = html;
  return cleaned(template.content);
}

function sanitizeHTML(root) {
  const box = document.createElement("div");
  box.append(cleaned(root));
  return box.innerHTML;
}

function snapshot() {
  return {title: title.value.trim(), body: sanitizeHTML(editor), kind: kind.value,
    slug: slug.value.trim()};
}

function checked(record) {
  if (record && typeof record.title === "string" && record.title.length <= 120 &&
      typeof record.body === "string" && record.body.length <= maxBody &&
      typeof record.slug === "string" && record.slug.length <= 64 &&
      ["post", "page"].includes(record.kind)) return record;
  throw new Error("原稿を読み込めませんでした。");
}

function status(message) {
  $("draft-status").textContent = message;
}

function save() {
  clearTimeout(timer);
  if (!dirty) return true;
  try {
    const record = checked(snapshot());
    localStorage.setItem(keyPrefix + id, JSON.stringify({...record, updated: Date.now()}));
    localStorage.setItem(lastKey, id);
    dirty = false;
    status("このブラウザーに保存済み");
    return true;
  } catch {
    status("保存できません。書き出しで原稿を保管してください。");
    return false;
  }
}

function changed() {
  dirty = true;
  status("保存中…");
  clearTimeout(timer);
  timer = setTimeout(save, 260);
}

function restore(key, record) {
  id = key;
  selection = undefined;
  dirty = false;
  title.value = record.title;
  slug.value = record.slug;
  kind.value = record.kind;
  editor.replaceChildren(parse(record.body));
  setPreview(false);
  status(record.updated ? "このブラウザーに保存済み" : "新しい原稿");
  try { localStorage.setItem(lastKey, id); } catch { /* editing still works */ }
}

function openDrafts() {
  if (!save()) return;
  const list = $("draft-list");
  list.replaceChildren();
  const records = [];
  try {
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i);
      if (!key?.startsWith(keyPrefix) || key === lastKey) continue;
      try {
        records.push([key.slice(keyPrefix.length), checked(JSON.parse(localStorage.getItem(key)))]);
      } catch { /* leave invalid entries in storage for manual recovery */ }
    }
  } catch {
    list.textContent = "このブラウザーでは下書きを読み込めません。";
  }
  records.sort(([, a], [, b]) => b.updated - a.updated);
  for (const [key, record] of records) {
    const row = document.createElement("div");
    row.className = "draft-row";
    const open = document.createElement("button");
    open.textContent = record.title || "無題の原稿";
    open.onclick = () => { restore(key, record); $("draft-dialog").close(); title.focus(); };
    row.append(open);
    const remove = document.createElement("button");
    remove.textContent = "削除";
    remove.onclick = () => {
      if (!confirm("この下書きを削除しますか？")) return;
      try { localStorage.removeItem(keyPrefix + key); } catch { status("削除できませんでした。"); return; }
      if (key === id) restore(crypto.randomUUID(), {title: "", body: "", slug: "", kind: "post"});
      row.remove();
      if (!list.children.length) list.textContent = "下書きはまだありません。";
    };
    row.append(remove);
    list.append(row);
  }
  if (!list.textContent) list.textContent = "下書きはまだありません。";
  $("draft-dialog").showModal();
}

function setPreview(active) {
  previewing = active;
  $("preview").hidden = !active;
  editor.parentElement.hidden = active;
  document.querySelector(".writer-toolbar").hidden = active;
  $("preview-button").setAttribute("aria-pressed", String(active));
  $("preview-button").textContent = active ? "編集に戻る" : "プレビュー";
  if (active) {
    $("preview-title").textContent = title.value.trim() || "無題の原稿";
    $("preview-body").replaceChildren(cleaned(editor));
  }
}

function retainSelection() {
  const range = window.getSelection();
  if (range.rangeCount && editor.contains(range.getRangeAt(0).commonAncestorContainer)) {
    selection = range.getRangeAt(0).cloneRange();
  }
  for (const button of document.querySelectorAll("[data-command][aria-pressed]")) {
    button.setAttribute("aria-pressed", String(editor.contains(range.anchorNode) &&
      document.queryCommandState(button.dataset.command)));
  }
}

function format(command, value) {
  editor.focus();
  const range = window.getSelection();
  if (selection && editor.contains(selection.commonAncestorContainer)) {
    range.removeAllRanges();
    range.addRange(selection);
  }
  document.execCommand(command, false, value);
  retainSelection();
  changed();
}

function escapeMarkdown(text) {
  return text.replace(/[\\`*_{}\[\]<>#~!|]/g, "\\$&")
    .replace(/^(\s*)([-+])(?=\s)/gm, "$1\\$2").replace(/^(\s*\d+)\.(?=\s)/gm, "$1\\.");
}

function markdown(root) {
  function render(node) {
    if (node.nodeType === Node.TEXT_NODE) return escapeMarkdown(node.data.replace(/\u00a0/g, " "));
    const content = () => Array.from(node.childNodes, render).join("");
    switch (node.tagName) {
      case "P": case "DIV": return content().trim() + "\n\n";
      case "H2": case "H3": return "#".repeat(Number(node.tagName[1])) + " " + content().trim() + "\n\n";
      case "BLOCKQUOTE": return content().trim().split("\n").map((line) => "> " + line).join("\n") + "\n\n";
      case "BR": return "  \n";
      case "STRONG": case "B": case "EM": case "I": {
        const marker = ["B", "STRONG"].includes(node.tagName) ? "**" : "*";
        return content().replace(/\S(?:.*\S)?/g, (text) => marker + text + marker);
      }
      case "A": return "[" + content().trim() + "](" + node.href + ")";
      case "UL": case "OL": {
        const items = Array.from(node.children).filter((item) => item.tagName === "LI");
        return items.map((item, index) => {
          const prefix = node.tagName === "UL" ? "- " : `${index + 1}. `;
          return prefix + render(item).trim().replaceAll("\n", "\n" + " ".repeat(prefix.length));
        }).join("\n") + "\n\n";
      }
      default: return content();
    }
  }
  return render(root).trim() + "\n";
}

function filename(value) {
  return value.normalize("NFKC").toLowerCase().replace(/[^\p{L}\p{N}\p{M}]+/gu, "-")
    .replace(/^-|-$/g, "").slice(0, 64).replace(/-$/, "") || "article";
}

function download(extension) {
  const record = snapshot();
  const titleText = record.title || "無題の原稿";
  const name = filename(record.slug || titleText);
  let data;
  let type;
  if (extension === "md") {
    data = "---\n" + JSON.stringify({title: titleText, kind: record.kind, slug: name}) + "\n---\n" + markdown(parse(record.body));
    type = "text/markdown;charset=utf-8";
  } else {
    const heading = document.createElement("h1");
    heading.textContent = titleText;
    const label = document.createElement("title");
    label.textContent = titleText;
    data = '<!doctype html><html lang="ja"><head><meta charset="utf-8">' +
      '<meta name="viewport" content="width=device-width,initial-scale=1">' + label.outerHTML +
      '<style>body{width:min(46rem,calc(100% - 2rem));margin:3rem auto;font:1.05rem/1.7 system-ui,sans-serif;overflow-wrap:anywhere}blockquote{border-inline-start:.2rem solid #666;padding-inline-start:1rem}</style>' +
      '</head><body><main>' + heading.outerHTML + record.body + '</main></body></html>';
    type = "text/html;charset=utf-8";
  }
  const url = URL.createObjectURL(new Blob([data], {type}));
  const link = document.createElement("a");
  link.href = url;
  link.download = name + "." + extension;
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

async function translate(bytes, stream, limit) {
  const reader = new Blob([bytes]).stream().pipeThrough(stream).getReader();
  const chunks = [];
  let size = 0;
  for (;;) {
    const {value, done} = await reader.read();
    if (done) break;
    size += value.length;
    if (size > limit) {
      await reader.cancel();
      throw new Error("記事が長すぎます。HTMLを書き出してください。");
    }
    chunks.push(value);
  }
  return new Uint8Array(await new Blob(chunks).arrayBuffer());
}

async function share() {
  const out = $("share-url");
  const error = $("share-error");
  $("share-field").hidden = true;
  $("copy").hidden = true;
  error.textContent = "リンクを作成中…";
  $("share-dialog").showModal();
  try {
    const record = checked(snapshot());
    if (!record.title || !editor.textContent.trim()) throw new Error("タイトルと本文を入力してください。");
    const encoded = new TextEncoder().encode(JSON.stringify(record));
    const compressed = await translate(encoded, new CompressionStream("gzip"), maxShare);
    const data = btoa(String.fromCharCode(...compressed)).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
    const url = new URL(location.href);
    url.hash = "read=" + data;
    url.search = "";
    out.value = url.href;
    error.textContent = "";
    $("share-field").hidden = false;
    $("copy").hidden = false;
  } catch (reason) {
    error.textContent = reason.message || "リンクを作成できませんでした。";
  }
}

async function readShared(encoded) {
  document.body.classList.add("reader");
  try {
    if (!/^[a-zA-Z0-9_-]{1,24000}$/.test(encoded)) throw new Error();
    const bytes = Uint8Array.from(atob(encoded.replaceAll("-", "+").replaceAll("_", "/")), (c) => c.charCodeAt(0));
    const raw = await translate(bytes, new DecompressionStream("gzip"), maxBody * 4);
    const record = checked(JSON.parse(new TextDecoder("utf-8", {fatal: true}).decode(raw)));
    $("reader-title").textContent = record.title;
    $("reader-body").replaceChildren(parse(record.body));
    document.title = record.title + " · MoonPress";
    $("reader").hidden = false;
  } catch {
    $("reader-error").textContent = "この共有リンクは開けません。送り主から新しいリンクを受け取ってください。";
    $("reader-error").hidden = false;
  }
}

function publishDocument() {
  const record = snapshot();
  if (!record.title || !editor.textContent.trim()) {
    status("公開するタイトルと本文を入力してください。");
    return;
  }
  const body = markdown(parse(record.body));
  if (new TextEncoder().encode(body).length > 16000) {
    status("公開できる本文はUTF-8で16,000バイトまでです。");
    return;
  }
  if (!save()) return;
  const document = {title: record.title, slug: filename(record.slug || record.title),
    kind: record.kind, markdown: body};
  const bytes = new TextEncoder().encode(JSON.stringify(document));
  const encoded = btoa(String.fromCharCode(...bytes)).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
  const url = "https://moonpress-publisher.f-kotaro-0530.chatgpt.site/#draft=" + encoded;
  window.open(url, "_blank", "noopener,noreferrer");
  status("公開先の確認画面を開きました。");
}

function startEditor() {
  $("workspace").hidden = false;
  try {
    const last = localStorage.getItem(lastKey);
    const stored = last && localStorage.getItem(keyPrefix + last);
    if (stored) restore(last, checked(JSON.parse(stored)));
  } catch {
    status("前回の下書きを開けませんでした。");
  }
  document.addEventListener("selectionchange", retainSelection);
  for (const node of [title, editor, slug, kind]) node.addEventListener("input", changed);
  editor.addEventListener("paste", (event) => {
    const clipboard = event.clipboardData;
    if (!clipboard) return;
    event.preventDefault();
    const rich = clipboard.getData("text/html");
    const box = document.createElement("div");
    if (rich) box.append(parse(rich));
    if (box.textContent.trim()) format("insertHTML", box.innerHTML);
    else format("insertText", clipboard.getData("text/plain"));
  });
  editor.addEventListener("drop", (event) => event.preventDefault());
  document.querySelector(".writer-toolbar").addEventListener("mousedown", (event) => {
    if (event.target.closest("button")) event.preventDefault();
  });
  for (const button of document.querySelectorAll("[data-command]")) {
    button.onclick = () => format(button.dataset.command);
  }
  $("paragraph").onchange = (event) => format("formatBlock", event.target.value);
  $("insert-link").onclick = () => {
    $("link-error").textContent = "";
    $("link-url").value = "";
    $("link-dialog").showModal();
  };
  $("link-form").onsubmit = (event) => {
    event.preventDefault();
    const url = linkURL($("link-url").value.trim());
    if (!url) { $("link-error").textContent = "https:// から始まるURLを入力してください。"; return; }
    $("link-dialog").close();
    if (!selection || selection.collapsed) {
      const link = document.createElement("a");
      link.href = url;
      link.textContent = url;
      format("insertHTML", link.outerHTML);
    } else format("createLink", url);
  };
  $("new").onclick = () => {
    if (!save()) return;
    restore(crypto.randomUUID(), {title: "", body: "", slug: "", kind: "post"});
    title.focus();
  };
  $("open").onclick = openDrafts;
  $("preview-button").onclick = () => setPreview(!previewing);
  $("share-button").onclick = share;
  if (location.origin === "https://furukawa1020.github.io" &&
      location.pathname === "/MoonPress/write.html") {
    $("publish-button").hidden = false;
    $("publish-button").onclick = publishDocument;
  }
  $("copy").onclick = async () => {
    $("share-url").select();
    try {
      await navigator.clipboard.writeText($("share-url").value);
      $("share-error").textContent = "リンクをコピーしました。";
    } catch {
      $("share-error").textContent = "選択したURLをコピーしてください。";
    }
  };
  $("download").onclick = () => download("md");
  $("export").onclick = () => download("html");
  for (const button of document.querySelectorAll("[data-close]")) {
    button.onclick = () => $(button.dataset.close).close();
  }
  window.addEventListener("pagehide", save);
}

if (location.hash.startsWith("#read=")) readShared(location.hash.slice(6));
else startEditor();

window.addEventListener("hashchange", () => location.reload());
