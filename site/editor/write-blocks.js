const kinds = new Map([
  ["p", "段落"], ["h2", "見出し"], ["h3", "小見出し"], ["blockquote", "引用"],
  ["ul", "箇条書き"], ["ol", "番号付きリスト"], ["tasks", "タスクリスト"],
  ["table", "表"], ["hr", "横線"], ["pre", "コード"], ["img", "画像"],
]);
const inlineBlocks = new Set(["p", "h2", "h3", "blockquote"]);

function button(label, action) {
  const element = document.createElement("button");
  element.type = "button";
  element.textContent = label;
  element.onclick = action;
  return element;
}

function editable(element, label, multiline = true) {
  element.contentEditable = "true";
  element.setAttribute("role", "textbox");
  element.setAttribute("aria-label", label);
  if (multiline) element.setAttribute("aria-multiline", "true");
}

function taskItem() {
  const item = document.createElement("li");
  const box = document.createElement("input");
  box.type = "checkbox";
  const text = document.createElement("span");
  text.append(document.createElement("br"));
  item.append(box, text);
  return item;
}

function tableCells(row, tag, length) {
  for (let i = 0; i < length; i++) row.append(document.createElement(tag));
}

function taskList(node) {
  return node?.nodeName === "UL" && Array.from(node.children).some(item =>
    item.firstElementChild?.matches('input[type="checkbox"]'));
}

function fresh(tag) {
  if (tag === "tasks") {
    const list = document.createElement("ul");
    list.append(taskItem());
    return list;
  }
  const node = document.createElement(tag);
  if (tag === "table") {
    tableCells(node.createTHead().insertRow(), "th", 2);
    tableCells(node.createTBody().insertRow(), "td", 2);
  } else if (tag === "ul" || tag === "ol") {
    const item = document.createElement("li");
    item.append(document.createElement("br"));
    node.append(item);
  } else if (!["hr", "pre", "img"].includes(tag)) {
    node.append(document.createElement("br"));
  }
  return node;
}

export function makeBlocks(body, notify, imageURL) {
  const by = id => document.getElementById(id);
  const add = by("block-add");
  const picker = by("block-picker");
  const search = by("block-search");
  const choices = by("block-choices");
  const outline = by("block-outline");
  const undo = by("block-undo");
  const redo = by("block-redo");
  const imageDialog = by("image-dialog");
  const history = [];
  const forward = [];
  let active;
  let focused;
  let insertion;
  let engine;
  const engineLoad = WebAssembly.instantiateStreaming(fetch(new URL("block-engine.wasm", import.meta.url)))
    .then(({instance}) => { engine = instance.exports; }).catch(() => {});

  function rows() { return Array.from(body.children); }

  function setActive(row) {
    if (active === row) return;
    active?.classList.remove("active-block");
    active = row;
    focused = undefined;
    active?.classList.add("active-block");
  }

  function focus(row) {
    setActive(row);
    (row?.querySelector("[contenteditable],textarea") ?? row ?? add).focus();
  }

  function refresh() {
    undo.disabled = history.length === 0;
    redo.disabled = forward.length === 0;
    if (!outline.parentElement.open) return;
    outline.replaceChildren(...rows().map((row, index) => {
      const node = row.read()[0];
      const kind = taskList(node) ? "tasks" : node?.nodeName === "FIGURE" ? "img" : (node?.nodeName.toLowerCase() ?? "");
      const preview = (node?.textContent ?? "").trim().replace(/\s+/g, " ").slice(0, 42);
      const label = (index + 1) + ". " + (kinds.get(kind) ?? "本文");
      const item = document.createElement("li");
      item.append(button(preview ? label + " · " + preview : label, () => focus(row)));
      return item;
    }));
  }

  function changed() {
    refresh();
    notify();
  }

  function copyRow(row) {
    return wrap(row.read().map(node => node.cloneNode(true)));
  }

  function state(changedRow) {
    const before = rows().map(row => row === changedRow ? copyRow(row) : row);
    return {rows: before, selected: rows().indexOf(active)};
  }

  function remember(changedRow) {
    history.push(state(changedRow));
    if (history.length > 40) history.shift();
    forward.length = 0;
  }

  function restore(from, to) {
    const previous = from.pop();
    if (!previous) return;
    to.push(state());
    body.replaceChildren(...previous.rows);
    setActive(undefined);
    focus(previous.rows[previous.selected]);
    changed();
  }

  function wrap(nodes) {
    const row = document.createElement("section");
    row.className = "writer-block";
    row.tabIndex = -1;
    const content = document.createElement("div");
    content.className = "writer-block-content";
    const node = nodes[0];
    const tag = node.nodeName.toLowerCase();
    const actions = document.createElement("div");
    actions.className = "writer-block-actions";

    if (tag === "pre") {
      const code = document.createElement("textarea");
      code.value = node.textContent;
      code.setAttribute("aria-label", "コード");
      code.addEventListener("input", () => { node.textContent = code.value; });
      content.append(code);
    } else {
      content.append(...nodes);
      if (tag === "figure" && node.querySelector("img")) {
        const caption = node.querySelector("figcaption") ?? node.appendChild(document.createElement("figcaption"));
        editable(caption, "画像の説明");
      } else if (tag === "table") {
        const setupCells = tableRow => Array.from(tableRow.cells).forEach((cell, index) =>
          editable(cell, (cell.nodeName === "TH" ? "表の見出し " : "セル ") + (index + 1)));
        Array.from(node.rows).forEach(setupCells);
        function selectedCell() {
          const cell = focused?.closest("th,td");
          return cell && node.contains(cell) ? cell : node.rows[0]?.cells[0];
        }
        actions.append(button("選択行を削除", () => {
          const cell = selectedCell();
          if (!cell || node.rows.length < 2) return;
          remember(row);
          cell.parentElement.remove();
          focus(row);
          changed();
        }));
        actions.append(button("選択列を削除", () => {
          const cell = selectedCell();
          if (!cell || Array.from(node.rows).some(tableRow => tableRow.cells.length < 2)) return;
          const index = cell.cellIndex;
          remember(row);
          for (const tableRow of node.rows) {
            if (tableRow.cells[index]) tableRow.deleteCell(index);
            setupCells(tableRow);
          }
          focus(row);
          changed();
        }));
        actions.append(button("先頭行の見出しを切り替え", () => {
          const first = node.rows[0];
          if (!first) return;
          const useHeading = first.cells[0]?.nodeName !== "TH";
          remember(row);
          for (const cell of Array.from(first.cells)) {
            const replacement = document.createElement(useHeading ? "th" : "td");
            replacement.append(...Array.from(cell.childNodes, child => child.cloneNode(true)));
            cell.replaceWith(replacement);
          }
          if (useHeading) (node.tHead ?? node.createTHead()).append(first);
          else (node.tBodies[0] ?? node.createTBody()).prepend(first);
          setupCells(first);
          focus(row);
          changed();
        }));
        actions.append(button("行を追加", () => {
          remember(row);
          const tableRow = (node.tBodies[0] ?? node.createTBody()).insertRow();
          tableCells(tableRow, "td", node.rows[0]?.cells.length || 2);
          setupCells(tableRow);
          tableRow.cells[0].focus();
          changed();
        }), button("列を追加", () => {
          if (!node.rows.length) return;
          remember(row);
          for (const tableRow of node.rows) {
            tableCells(tableRow, tableRow.parentElement.nodeName === "THEAD" ? "th" : "td", 1);
            setupCells(tableRow);
          }
          node.rows[0].lastElementChild.focus();
          changed();
        }));
      } else if (taskList(node)) {
        const setupItem = item => {
          const box = item.firstElementChild;
          if (!box?.matches('input[type="checkbox"]')) return;
          box.disabled = false;
          box.setAttribute("aria-label", "タスクの完了");
          box.addEventListener("change", () => {
            box.toggleAttribute("checked", box.checked);
            changed();
          });
          if (box.nextElementSibling) editable(box.nextElementSibling, "タスクの本文");
        };
        Array.from(node.children).forEach(setupItem);
        actions.append(button("項目を追加", () => {
          remember(row);
          const item = taskItem();
          node.append(item);
          setupItem(item);
          item.lastElementChild.focus();
          changed();
        }));
      } else if (!["hr", "img"].includes(tag)) {
        const target = inlineBlocks.has(tag) && nodes.length === 1 ? node : content;
        editable(target, kinds.get(tag) ?? "本文");
      }
    }

    if (nodes.length === 1 && inlineBlocks.has(tag)) {
      const selector = document.createElement("select");
      selector.setAttribute("aria-label", "ブロックの種類");
      for (const value of ["p", "h2", "h3", "blockquote"]) selector.add(new Option(kinds.get(value), value));
      if (!Array.from(selector.options).some(option => option.value === tag)) {
        selector.add(new Option(kinds.get(tag), tag));
      }
      selector.value = tag;
      selector.onchange = () => {
        const replacement = document.createElement(selector.value);
        replacement.append(...Array.from(node.childNodes, child => child.cloneNode(true)));
        remember();
        const changedRow = wrap([replacement]);
        row.replaceWith(changedRow);
        focus(changedRow);
        changed();
      };
      actions.prepend(selector);
    }

    if (nodes.length === 1 && ["ul", "ol"].includes(tag) && !taskList(node)) {
      actions.append(button(tag === "ul" ? "番号付きに変更" : "箇条書きに変更", () => {
        const replacement = document.createElement(tag === "ul" ? "ol" : "ul");
        replacement.append(...Array.from(node.childNodes, child => child.cloneNode(true)));
        remember();
        const changedRow = wrap([replacement]);
        row.replaceWith(changedRow);
        focus(changedRow);
        changed();
      }));
    }

    const image = tag === "img" ? node : tag === "figure" ? node.querySelector("img") : null;
    if (image && tag === "img") {
      actions.append(button("キャプションを追加", () => {
        const figure = document.createElement("figure");
        figure.append(image.cloneNode(true), document.createElement("figcaption"));
        remember();
        const replacement = wrap([figure]);
        row.replaceWith(replacement);
        setActive(replacement);
        replacement.querySelector("figcaption").focus();
        changed();
      }));
    }
    if (image) {
      actions.append(button("画像を編集", () => {
        const form = imageDialog.querySelector("form");
        form.elements.src.value = image.getAttribute("src");
        form.elements.alt.value = image.alt;
        form.elements.src.setCustomValidity("");
        imageDialog.showModal();
        form.onsubmit = event => {
          event.preventDefault();
          const source = imageURL(form.elements.src.value);
          if (!source) {
            form.elements.src.setCustomValidity("HTTPSの画像URLを入力してください。");
            form.elements.src.reportValidity();
            return;
          }
          remember(row);
          image.src = source;
          image.alt = form.elements.alt.value.trim();
          imageDialog.close();
          focus(row);
          changed();
        };
      }));
    }

    function move(step) {
      const all = rows();
      const position = all.indexOf(row);
      const target = engine?.movement_index(all.length, position, step) ?? (position + step);
      if (target < 0 || target >= all.length) return;
      remember();
      body.insertBefore(row, step > 0 ? all[target].nextSibling : all[target]);
      focus(row);
      changed();
    }

    function duplicate() {
      remember();
      const copy = copyRow(row);
      row.after(copy);
      focus(copy);
      changed();
    }

    function remove() {
      const all = rows();
      const position = all.indexOf(row);
      const next = engine?.selection_after_removal(all.length, position) ?? Math.min(position, all.length - 2);
      remember();
      row.remove();
      setActive(undefined);
      focus(rows()[next]);
      changed();
    }

    row.addEventListener("focusin", event => {
      setActive(row);
      if (event.target.matches("[contenteditable]")) focused = event.target;
    });
    row.addEventListener("keydown", event => {
      if (event.isComposing) return;
      if ((event.ctrlKey || event.metaKey) && event.shiftKey && !event.altKey && event.key.toLowerCase() === "d") {
        event.preventDefault();
        duplicate();
      }
      if ((event.ctrlKey || event.metaKey) && event.shiftKey && !event.altKey && event.key === "Backspace") {
        event.preventDefault();
        remove();
      }
      if (event.key === "/" && !event.altKey && !event.ctrlKey && !event.metaKey &&
          event.target.matches("p[contenteditable]") && !event.target.textContent.trim()) {
        event.preventDefault();
        openPicker(row, true);
      }
      if (event.altKey && event.shiftKey && ["ArrowUp", "ArrowDown"].includes(event.key)) {
        event.preventDefault();
        move(event.key === "ArrowUp" ? -1 : 1);
      }
    });
    actions.append(button("＋ この下に追加", () => openPicker(row)), button("上へ", () => move(-1)),
      button("下へ", () => move(1)), button("複製", duplicate), button("削除", remove));
    row.append(content, actions);
    row.read = () => tag === "pre" ? [node] : Array.from(content.childNodes);
    return row;
  }

  function insert(node, {after, replace}) {
    const all = rows();
    const selected = all.indexOf(after);
    remember();
    const row = wrap([node]);
    if (replace && selected >= 0) {
      after.replaceWith(row);
    } else {
      const position = engine?.insertion_index(all.length, selected) ?? (selected < 0 ? all.length : selected + 1);
      body.insertBefore(row, all[position] ?? null);
    }
    focus(row);
    changed();
  }

  function openPicker(after, replace = false) {
    insertion = {after, replace};
    search.value = "";
    filter();
    picker.showModal();
    search.focus();
  }

  function filter() {
    const query = search.value.trim().toLowerCase();
    for (const choice of choices.children) {
      choice.hidden = !choice.textContent.includes(query) && !choice.dataset.kind.includes(query);
    }
    by("block-empty").hidden = Array.from(choices.children).some(choice => !choice.hidden);
  }

  async function choose(tag) {
    const target = insertion;
    picker.close();
    await engineLoad;
    if (tag !== "img") {
      insert(fresh(tag), target);
      return;
    }
    const form = imageDialog.querySelector("form");
    form.reset();
    form.elements.src.setCustomValidity("");
    imageDialog.showModal();
    form.onsubmit = event => {
      event.preventDefault();
      const source = imageURL(form.elements.src.value);
      if (!source) {
        form.elements.src.setCustomValidity("HTTPSの画像URLを入力してください。");
        form.elements.src.reportValidity();
        return;
      }
      const img = fresh(tag);
      img.referrerPolicy = "no-referrer";
      img.src = source;
      img.alt = form.elements.alt.value.trim();
      imageDialog.close();
      insert(img, target);
    };
  }

  for (const [tag, label] of kinds) {
    const choice = button(label, () => choose(tag));
    choice.dataset.kind = tag;
    choices.append(choice);
  }
  picker.querySelector("form").addEventListener("submit", event => {
    event.preventDefault();
    picker.close();
  });
  search.addEventListener("input", filter);
  search.addEventListener("keydown", event => {
    if (event.isComposing || !["Enter", "ArrowDown"].includes(event.key)) return;
    event.preventDefault();
    const first = choices.querySelector("button:not([hidden])");
    if (event.key === "Enter") first?.click();
    else first?.focus();
  });
  add.onclick = () => openPicker(active);
  undo.onclick = () => restore(history, forward);
  redo.onclick = () => restore(forward, history);
  outline.parentElement.addEventListener("toggle", refresh);
  body.addEventListener("input", refresh);
  imageDialog.querySelector("[name=src]").oninput = event => event.target.setCustomValidity("");
  imageDialog.querySelector("[type=button]").onclick = () => imageDialog.close();

  return {
    reset(fragment) {
      setActive(undefined);
      history.length = 0;
      forward.length = 0;
      const nodes = Array.from(fragment.childNodes);
      body.replaceChildren(...(nodes.length ? nodes : [fresh("p")]).map(node => wrap([node])));
      refresh();
    },
    read() {
      const result = document.createDocumentFragment();
      for (const row of rows()) for (const node of row.read()) result.append(node.cloneNode(true));
      return result;
    },
    current() {
      if (focused?.isConnected) return focused;
      return (active ?? rows()[0])?.querySelector("[contenteditable]");
    },
  };
}
