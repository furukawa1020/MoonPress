const by = id => document.getElementById(id);
const record = JSON.parse(by("record").textContent);
const body = by("body");
const allowed = new Set(["p", "div", "h2", "h3", "blockquote", "strong", "em", "b", "i", "ul", "ol", "li", "br", "hr", "pre", "a", "img"]);
let selection;
let busy = false;
let dirty = false;

function href(value) {
  try {
    const parsed = new URL(value);
    if (parsed.protocol === "https:" && !parsed.username && !parsed.password) return parsed.href;
  } catch { /* refuse malformed URLs */ }
  return "";
}
function encode(root) {
  return Array.from(root.childNodes).flatMap(node => {
    if (node.nodeType === Node.TEXT_NODE) return [node.data];
    if (node.nodeType !== Node.ELEMENT_NODE || node.matches(".block-code") || ["SCRIPT", "STYLE", "IFRAME"].includes(node.tagName)) return [];
    const tag = node.tagName.toLowerCase();
    const children = tag === "pre" ? [node.hidden ? node.textContent : node.innerText] : encode(node);
    if (!allowed.has(tag)) return children;
    if (tag === "img") {
      const src = href(node.getAttribute("src"));
      return src ? [{tag, src, alt:node.alt, children:[]}] : [];
    }
    if (tag === "a") {
      const url = href(node.getAttribute("href"));
      return url ? [{tag, href:url, children}] : children;
    }
    return [{tag, children}];
  });
}
function fill(parent, nodes) {
  for (const node of nodes) {
    if (typeof node === "string") { parent.append(node); continue; }
    if (!allowed.has(node.tag)) continue;
    const element = document.createElement(node.tag);
    if (node.tag === "img") {
      const src = href(node.src);
      if (!src) continue;
      element.referrerPolicy = "no-referrer";
      element.loading = "lazy";
      element.alt = node.alt ?? "";
      element.src = src;
    }
    if (node.tag === "a") element.href = href(node.href);
    fill(element, node.children || []);
    parent.append(element);
  }
}
function say(value) { by("status").textContent = value; }
function format(command, value) {
  const editor = selection?.commonAncestorContainer.parentElement?.closest(".block-content");
  (editor ?? body).focus();
  const current = getSelection();
  if (selection && body.contains(selection.commonAncestorContainer)) {
    current.removeAllRanges();
    current.addRange(selection);
  }
  document.execCommand(command, false, value);
  dirty = true;
}
function preview() {
  const panel = by("preview");
  panel.hidden = !panel.hidden;
  by("surface").hidden = !panel.hidden;
  by("preview-button").textContent = panel.hidden ? "プレビュー" : "編集に戻る";
  if (panel.hidden) return;
  const title = document.createElement("h1");
  title.textContent = by("title").value.trim();
  panel.replaceChildren(title);
  fill(panel, snapshot());
}
function slugFor(value) {
  return value.normalize("NFKC").toLowerCase().replace(/[^\p{L}\p{N}\p{M}]+/gu, "-")
    .replace(/^-|-$/g, "").slice(0, 60).replace(/-$/, "") || "article";
}
async function save(publish) {
  if (busy) return;
  const title = by("title").value.trim();
  const nodes = snapshot();
  if (!title || (!body.textContent.trim() && !body.querySelector("img"))) { say("タイトルと本文を入力してください。"); return; }
  const slug = record.slug || slugFor(by("slug").value.trim() || title);
  if (publish && !confirm("「" + title + "」を固定URLで公開しますか？")) return;
  const snapshot = {title, slug, kind:by("kind").value, body:nodes, excerpt:by("excerpt").value, version:record.version, publish};
  busy = true;
  by("save").disabled = by("publish").disabled = true;
  say(publish ? "公開中…" : "保存中…");
  dirty = false;
  try {
    const r = await fetch(record.endpoint, {method:"POST", headers:{"Content-Type":"application/json"},
      body:JSON.stringify(snapshot)});
    const result = await r.json();
    if (!r.ok) throw Error(result.error || "保存に失敗しました。");
    record.slug = slug;
    record.version = result.version;
    by("slug").value = slug;
    by("slug").readOnly = true;
    history.replaceState(null, "", result.editor);
    const removal = by("unpublish-form");
    removal.elements.slug.value = slug;
    removal.elements.version.value = result.version;
    removal.hidden = !(record.published || publish);
    if (publish) {
      record.published = true;
      by("live").href = result.url;
      by("live").hidden = false;
      say("公開済みです。");
    } else say("下書きを保存しました。");
  } catch (error) {
    say(error.message || "保存に失敗しました。");
    dirty = true;
  } finally {
    busy = by("save").disabled = by("publish").disabled = false;
  }
}
by("title").value = record.title;
by("kind").value = record.kind;
by("slug").value = record.slug;
by("excerpt").value = record.excerpt ?? "";
by("slug").readOnly = Boolean(record.slug);
fill(body, record.body);
if (record.published) {
  by("live").href = record.endpoint.replace(/^\/admin\//, "/p/").replace(/\/documents$/, "") + "/" + encodeURIComponent(record.slug);
  by("live").hidden = false;
}
document.addEventListener("selectionchange", () => {
  const current = getSelection();
  if (current.rangeCount && body.contains(current.getRangeAt(0).commonAncestorContainer)) {
    selection = current.getRangeAt(0).cloneRange();
  }
});
document.querySelector(".toolbar").addEventListener("mousedown", event => {
  if (event.target.closest("button")) event.preventDefault();
});
for (const button of document.querySelectorAll("[data-format]")) button.onclick = () => format(button.dataset.format);
by("block").onchange = e => format("formatBlock", e.target.value);
body.addEventListener("paste", event => {
  if (event.target.matches("textarea, input")) return;
  event.preventDefault();
  format("insertText", event.clipboardData?.getData("text/plain") || "");
});
body.addEventListener("drop", event => event.preventDefault());
by("insert-link").onclick = () => {
  if (!selection || selection.collapsed || !body.contains(selection.commonAncestorContainer)) {
    say("リンクにする文字を選択してください。");
    return;
  }
  const entered = prompt("HTTPSのURL");
  if (entered === null) return;
  const url = href(entered);
  if (!url) { say("有効なHTTPSのURLを入力してください。"); return; }
  format("createLink", url);
};
const codeDialog = by("code-dialog");
const codeText = by("code-text");
by("insert-code").onclick = () => {
  codeText.value = selection && body.contains(selection.commonAncestorContainer) ? selection.toString() : "";
  codeDialog.showModal();
  codeText.focus();
};
by("cancel-code").onclick = () => codeDialog.close();
by("code-form").onsubmit = event => {
  event.preventDefault();
  const block = document.createElement("pre");
  block.textContent = codeText.value;
  codeDialog.close();
  format("insertHTML", block.outerHTML + "<p><br></p>");
};
by("preview-button").onclick = preview;
by("save").onclick = () => save(false);
by("publish").onclick = () => save(true);
for (const id of ["title", "body", "kind", "slug", "excerpt"]) by(id).addEventListener("input", () => { dirty = true; });
by("unpublish-form").onsubmit = () => {
  if (busy || !confirm("この記事の公開を取り下げますか？")) return false;
  if (dirty && !confirm("保存していない変更を破棄しますか？")) return false;
  dirty = false;
  return true;
};
window.addEventListener("keydown", event => {
  if ((event.ctrlKey || event.metaKey) && !event.altKey && event.key.toLowerCase() === "s") {
    event.preventDefault();
    save(false);
  }
});
window.addEventListener("beforeunload", event => { if (dirty || busy) event.preventDefault(); });
