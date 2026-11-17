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

async function insertBlock(nodes) {
  await loadBlockEngine();
  if (!engine || !blockEditor) return null;
  const rows = blocks();
  const index = engine.insertion_index(rows.length, rows.indexOf(selectedBlock));
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
  const editor = element("div");
  editor.className = "block-content";
  editor.contentEditable = "true";
  editor.setAttribute("role", "textbox");
  editor.setAttribute("aria-label", "ブロック本文");
  editor.setAttribute("aria-multiline", "true");
  fill(editor, nodes);
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
  row.addEventListener("focusin", () => selectBlock(row));
  return row;
}

function focusBlock(row) {
  const editor = content(row);
  const input = editor.querySelector("textarea, input");
  (input ?? editor).focus();
  if (!input && editor.firstChild) {
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
  selectedBlock?.classList.remove("is-active");
  selectedBlock = row;
  selectedBlock?.classList.add("is-active");
}
function snapshot() { return blockEditor ? blockData() : encode(body); }

function setupBlocks() {
  const toggle = by("block-editor");
  toggle.addEventListener("click", () => {
    const source = snapshot();
    const wasDirty = dirty;
    blockEditor = !blockEditor;
    selectBlock(null);
    body.replaceChildren();
    body.classList.toggle("with-blocks", blockEditor);
    body.contentEditable = String(!blockEditor);
    toggle.textContent = blockEditor ? "通常の編集に戻る" : "ブロックで編集";
    toggle.setAttribute("aria-pressed", String(blockEditor));
    if (blockEditor) {
      loadBlockEngine();
      const nodes = source.length ? source : [{tag:"p",children:[]}];
      for (const node of nodes) body.append(makeBlock([node]));
    } else fill(body, source);
    for (const callback of blockMounted) callback();
    dirty = wasDirty;
  });
}

document.addEventListener("DOMContentLoaded", setupBlocks);

function registerBlock(tag, label, create = () => [{tag, children:[]}]) {
  blockTypes.set(tag, {label, create});
}
function appendBlockMenu() {
  const dock = element("div");
  dock.className = "block-dock";
  const choices = element("select");
  choices.setAttribute("aria-label", "追加するブロック");
  for (const [tag, {label}] of blockTypes) {
    const option = element("option", label);
    option.value = tag;
    choices.append(option);
  }
  dock.append(choices, button("＋ 追加", async () => {
    const source = await blockTypes.get(choices.value).create();
    if (source) await insertBlock(source);
  }));
  body.before(dock);
  blockMounted.push(() => { dock.hidden = !blockEditor; });
  dock.hidden = !blockEditor;
}
document.addEventListener("DOMContentLoaded", appendBlockMenu);
