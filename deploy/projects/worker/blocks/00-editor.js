// Browser DOM adapter. Serialized articles keep the existing document format.
const blockTypes = new Map();
const blockCommands = new Map();
const blockMounted = [];
let selectedBlock = null;
let blockEditor = false;

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
  row.append(editor);
  row.addEventListener("focusin", () => selectBlock(row));
  return row;
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
      const nodes = source.length ? source : [{tag:"p",children:[]}];
      for (const node of nodes) body.append(makeBlock([node]));
    } else fill(body, source);
    for (const callback of blockMounted) callback();
    dirty = wasDirty;
  });
}

document.addEventListener("DOMContentLoaded", setupBlocks);
