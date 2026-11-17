// Browser DOM adapter. Serialized articles keep the existing document format.
const blockTypes = new Map();
const blockCommands = new Map();
const blockMounted = [];
const blockObservers = [];
function blocksChanged() { for (const update of blockObservers) update(); }
let selectedBlock = null;
let blockEditor = false;
let engine;
let engineLoad;

function loadBlockEngine() {
  if (!engineLoad) engineLoad = WebAssembly.instantiateStreaming(fetch("/block-engine.wasm"))
    .then(({instance}) => { engine = instance.exports; })
    .catch(() => { say("ブロックの操作を読み込めません。再読み込みしてください。"); });
  return engineLoad;
}

async function insertBlock(nodes, after = selectedBlock) {
  await loadBlockEngine();
  if (!engine || !blockEditor) return null;
  const rows = blocks();
  const index = engine.insertion_index(rows.length, rows.indexOf(after));
  const row = makeBlock(nodes);
  rememberBlocks();
  body.insertBefore(row, rows[index] ?? null);
  blocksChanged();
  dirty = true;
  selectBlock(row);
  focusBlock(row);
  return row;
}

function element(tag, text) {
  const node = document.createElement(tag);
  if (text) node.textContent = text;
  return node;
}

function button(label, callback) {
  const control = element("button", label);
  control.type = "button";
  control.addEventListener("click", callback);
  return control;
}

function blocks() { return Array.from(body.children); }
function content(row) { return row.querySelector(".block-content"); }
function blockData() { return blocks().flatMap(row => encode(content(row))); }
function makeBlock(nodes) {
  const row = element("section");
  row.className = "editor-block";
  row.tabIndex = -1;
  const editor = element("div");
  editor.className = "block-content";
  fill(editor, nodes);
  const tag = nodes.length === 1 && nodes[0]?.tag;
  const editable = ["p", "h2", "h3", "blockquote"].includes(tag) ? editor.firstChild : editor;
  if (!["img", "hr", "pre"].includes(tag)) {
    editable.contentEditable = "true";
    editable.setAttribute("role", "textbox");
    editable.setAttribute("aria-label", "ブロック本文");
    editable.setAttribute("aria-multiline", "true");
  }
  if (nodes.length === 1 && nodes[0]?.tag === "pre") {
    editor.contentEditable = "false";
    editor.removeAttribute("role");
    const code = element("textarea");
    code.className = "block-code";
    code.setAttribute("aria-label", "コードブロック");
    code.value = nodes[0].children.join("");
    editor.firstChild.hidden = true;
    code.addEventListener("input", () => { editor.firstChild.textContent = code.value; });
    editor.append(code);
  }
  row.append(editor);
  const direct = button("＋ この下に追加", () => openInserter(row));
  direct.className = "block-insert";
  row.append(direct);
  row.addEventListener("focusin", () => selectBlock(row));
  return row;
}

function focusBlock(row) {
  const editor = content(row);
  const input = editor.querySelector("textarea, input");
  const editable = editor.querySelector('[contenteditable="true"]') ?? editor;
  (input ?? (editable.isContentEditable ? editable : row)).focus();
  if (!input && editable.isContentEditable && editor.firstChild) {
    const range = document.createRange();
    range.selectNodeContents(editor.firstChild);
    range.collapse(true);
    const cursor = getSelection();
    cursor.removeAllRanges();
    cursor.addRange(range);
  }
}

function selectBlock(row) {
  if (selectedBlock === row) return;
  selection = undefined;
  selectedBlock?.classList.remove("is-active");
  selectedBlock = row;
  selectedBlock?.classList.add("is-active");
}
function snapshot() { return blockEditor ? blockData() : encode(body); }

function setupBlocks() {
  const toggle = by("block-editor");
  const changeMode = () => {
    const source = snapshot();
    const wasDirty = dirty;
    blockEditor = !blockEditor;
    selectBlock(null);
    insertTarget = null;
    body.replaceChildren();
    body.classList.toggle("with-blocks", blockEditor);
    document.querySelector(".toolbar").classList.toggle("block-mode", blockEditor);
    body.contentEditable = String(!blockEditor);
    if (blockEditor) {
      body.removeAttribute("role");
      body.removeAttribute("aria-label");
      body.removeAttribute("aria-multiline");
    } else {
      body.setAttribute("role", "textbox");
      body.setAttribute("aria-label", "本文");
      body.setAttribute("aria-multiline", "true");
    }
    toggle.textContent = blockEditor ? "通常の編集に戻る" : "ブロックで編集";
    toggle.setAttribute("aria-pressed", String(blockEditor));
    if (blockEditor) {
      loadBlockEngine();
      const nodes = source.length ? source : blockTypes.get("p").create();
      for (const node of nodes) body.append(makeBlock([node]));
    } else fill(body, source);
    for (const callback of blockMounted) callback();
    dirty = wasDirty;
  };
  toggle.addEventListener("click", changeMode);
  changeMode();
}

document.addEventListener("DOMContentLoaded", setupBlocks);

function registerBlock(tag, label, create = () => [{tag, children:[]}]) {
  blockTypes.set(tag, {label, create});
}
let blockChoice;
let insertTarget;
function openInserter(row) {
  selectBlock(row);
  insertTarget = row;
  blockChoice.focus();
}

function appendBlockMenu() {
  const dock = element("div");
  dock.className = "block-dock";
  const choices = element("select");
  choices.setAttribute("aria-label", "追加するブロック");
  blockChoice = choices;
  for (const [tag, {label}] of blockTypes) {
    const option = element("option", label);
    option.value = tag;
    choices.append(option);
  }
  dock.append(choices, button("＋ 追加", async () => {
    const target = insertTarget ?? selectedBlock;
    insertTarget = null;
    const source = await blockTypes.get(choices.value).create();
    if (source) await insertBlock(source, target);
  }));
  body.before(dock);
  blockMounted.push(() => { dock.hidden = !blockEditor; });
  dock.hidden = !blockEditor;
}
document.addEventListener("DOMContentLoaded", appendBlockMenu);
