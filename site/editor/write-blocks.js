const kinds = new Map([
  ["p", "段落"], ["h2", "見出し"], ["h3", "小見出し"], ["blockquote", "引用"],
  ["ul", "箇条書き"], ["ol", "番号付きリスト"], ["hr", "横線"], ["pre", "コード"], ["img", "画像"],
]);

function button(label, action) {
  const element = document.createElement("button");
  element.type = "button";
  element.textContent = label;
  element.onclick = action;
  return element;
}

export function makeBlocks(body, chooseKind, add, notify, imageDialog, imageURL) {
  let active;
  let engine;
  const engineLoad = WebAssembly.instantiateStreaming(fetch(new URL("block-engine.wasm", import.meta.url)))
    .then(({instance}) => { engine = instance.exports; }).catch(() => {});

  function rows() { return Array.from(body.children); }
  function setActive(row) {
    active?.classList.remove("active-block");
    active = row;
    active?.classList.add("active-block");
  }
  function focus(row) {
    setActive(row);
    (row?.querySelector("[contenteditable],textarea") ?? row)?.focus();
  }
  function wrap(node) {
    const row = document.createElement("section");
    row.className = "writer-block";
    row.tabIndex = -1;
    const content = document.createElement("div");
    content.className = "writer-block-content";
    const tag = node.nodeName.toLowerCase();
    if (tag === "pre") {
      const code = document.createElement("textarea");
      code.value = node.textContent;
      code.setAttribute("aria-label", "コード");
      code.addEventListener("input", () => { node.textContent = code.value; });
      content.append(code);
    } else {
      content.append(node);
      if (!["hr", "img"].includes(tag)) {
        const editable = ["p", "h2", "h3", "blockquote"].includes(tag) ? node : content;
        editable.contentEditable = "true";
        editable.setAttribute("role", "textbox");
        editable.setAttribute("aria-label", kinds.get(tag) ?? "本文");
        editable.setAttribute("aria-multiline", "true");
      }
    }
    function move(step) {
      const all = rows();
      const position = all.indexOf(row);
      const target = engine?.movement_index(all.length, position, step) ?? (position + step);
      if (target < 0 || target >= all.length) return;
      body.insertBefore(row, step > 0 ? all[target].nextSibling : all[target]);
      focus(row);
      notify();
    }
    row.addEventListener("focusin", () => setActive(row));
    row.addEventListener("keydown", event => {
      if (!event.altKey || !event.shiftKey || !["ArrowUp", "ArrowDown"].includes(event.key)) return;
      event.preventDefault();
      move(event.key === "ArrowUp" ? -1 : 1);
    });
    const actions = document.createElement("div");
    actions.className = "writer-block-actions";
    actions.append(button("上へ", () => move(-1)), button("下へ", () => move(1)),
      button("複製", () => {
        const copy = wrap(node.cloneNode(true));
        row.after(copy);
        focus(copy);
        notify();
      }), button("削除", () => {
        const all = rows();
        const position = all.indexOf(row);
        const next = engine?.selection_after_removal(all.length, position) ?? Math.min(position, all.length - 2);
        row.remove();
        setActive(undefined);
        if (rows()[next]) focus(rows()[next]);
        else add.focus();
        notify();
      }));
    row.append(content, actions);
    row.read = () => tag === "pre" ? [node] : Array.from(content.childNodes);
    return row;
  }

  function fresh(tag) {
    const node = document.createElement(tag);
    if (tag === "ul" || tag === "ol") node.append(document.createElement("li"));
    if (!["hr", "pre", "img"].includes(tag)) (node.firstChild ?? node).append(document.createElement("br"));
    return node;
  }
  function insert(node, after) {
    const all = rows();
    const selected = all.indexOf(after);
    const position = engine?.insertion_index(all.length, selected) ?? (selected < 0 ? all.length : selected + 1);
    const row = wrap(node);
    body.insertBefore(row, all[position] ?? null);
    focus(row);
    notify();
  }

  for (const [tag, label] of kinds) chooseKind.add(new Option(label, tag));
  add.onclick = async () => {
    const tag = chooseKind.value;
    const after = active;
    await engineLoad;
    if (tag === "img") {
      imageDialog.querySelector("form").reset();
      imageDialog.showModal();
      imageDialog.querySelector("form").onsubmit = event => {
        event.preventDefault();
        const source = imageURL(event.target.elements.src.value);
        if (!source) {
          event.target.elements.src.setCustomValidity("HTTPSの画像URLを入力してください。");
          event.target.elements.src.reportValidity();
          return;
        }
        const img = fresh(tag);
        img.referrerPolicy = "no-referrer";
        img.src = source;
        img.alt = event.target.elements.alt.value.trim();
        imageDialog.close();
        insert(img, after);
      };
    } else insert(fresh(tag), after);
  };
  imageDialog.querySelector("[name=src]").oninput = event => event.target.setCustomValidity("");
  imageDialog.querySelector("[type=button]").onclick = () => imageDialog.close();

  return {
    reset(fragment) {
      setActive(undefined);
      const nodes = Array.from(fragment.childNodes);
      body.replaceChildren(...(nodes.length ? nodes : [fresh("p")]).map(wrap));
    },
    read() {
      const result = document.createDocumentFragment();
      for (const row of rows()) for (const node of row.read()) result.append(node.cloneNode(true));
      return result;
    },
    current() { return (active ?? rows()[0])?.querySelector("[contenteditable]"); },
  };
}
