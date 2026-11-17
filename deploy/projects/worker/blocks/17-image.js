registerBlock("img", "画像", () => {
  const dialog = by("image-dialog");
  const form = by("image-form");
  form.reset();
  dialog.showModal();
  return new Promise(resolve => {
    form.onsubmit = event => {
      event.preventDefault();
      const src = href(form.elements.src.value);
      if (!src) {
        form.elements.src.setCustomValidity("HTTPS の画像URLを入力してください。");
        form.elements.src.reportValidity();
        return;
      }
      resolve([{tag:"img",src,alt:form.elements.alt.value.trim(),children:[]}]);
      dialog.close();
    };
    dialog.addEventListener("close", () => resolve(null), {once:true});
  });
});
by("image-form").elements.src.addEventListener("input", event => event.target.setCustomValidity(""));
by("cancel-image").addEventListener("click", () => by("image-dialog").close());
