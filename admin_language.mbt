///|
fn admin_language_quality(value : String) -> Int? {
  if value == "0" {
    return Some(0)
  }
  if value == "1" {
    return Some(1000)
  }
  let parts = value.split(".").map(p => p.to_owned()).to_array()
  if parts.length() != 2 ||
    (parts[0] != "0" && parts[0] != "1") ||
    parts[1].length() > 3 ||
    !parts[1].all(c => c.is_ascii_digit()) {
    return None
  }
  let mut weight = 100
  let mut result = if parts[0] == "1" { 1000 } else { 0 }
  for c in parts[1] {
    if parts[0] == "1" && c != '0' {
      return None
    }
    result += (c.to_int() - 48) * weight
    weight /= 10
  }
  Some(result)
}

///|
fn admin_browser_language(header : String) -> String {
  // No header preserves the existing per-page default; unsupported languages
  // use English. Browser requests normally supply Accept-Language.
  if header.is_empty() {
    return ""
  }
  let weights : Map[String, Int] = Map([])
  let order : Map[String, Int] = Map([])
  let mut index = 0
  for entry in header.to_lower().split(",") {
    let parts = entry
      .split(";")
      .map(p => p.trim(chars=" \t").to_owned())
      .to_array()
    let tag = parts[0]
    let language = if tag == "*" {
      "*"
    } else {
      tag.split("-").map(p => p.to_owned()).to_array()[0]
    }
    let quality = if parts.length() == 1 {
      Some(1000)
    } else if parts.length() == 2 && parts[1].has_prefix("q=") {
      admin_language_quality(parts[1][2:].to_owned())
    } else {
      None
    }
    if (language == "ja" || language == "en" || language == "*") &&
      quality is Some(q) {
      if !weights.contains(language) || q > weights[language] {
        weights[language] = q
        order[language] = index
      }
    }
    index += 1
  }
  let fallback = weights.get("*").unwrap_or(0)
  let ja = weights.get("ja").unwrap_or(fallback)
  let en = weights.get("en").unwrap_or(fallback)
  if ja > 0 &&
    (
      ja > en ||
      (
        ja == en &&
        order.get("ja").unwrap_or(2147483647) <
        order.get("en").unwrap_or(2147483647)
      )
    ) {
    "ja"
  } else {
    "en"
  }
}

///|
fn admin_language(accept : String, cookie : String) -> String {
  let mut preference = ""
  let mut seen = false
  for part in cookie.split(";") {
    if part.trim(chars=" \t").split_once("=") is Some((key, value)) {
      if key == "moonpress-language" {
        if seen {
          return admin_browser_language(accept)
        }
        seen = true
        preference = value.to_owned()
      }
    }
  }
  if preference == "ja" || preference == "en" {
    preference
  } else {
    admin_browser_language(accept)
  }
}

///|
fn admin_i18n(ja : String, en : String) -> String {
  "<!--mp:ja-->" + ja + "<!--mp:en-->" + en + "<!--mp:end-->"
}

///|
fn admin_render_language(html : String, language : String) -> String {
  let selected = if language == "ja" || language == "en" {
    language
  } else if html.has_prefix("<!doctype html><html lang=\"ja\">") {
    "ja"
  } else {
    "en"
  }
  let out = StringBuilder()
  let mut remaining = html
  while remaining.split_once("<!--mp:ja-->") is Some((before, rest)) {
    out.write_string(before.to_owned())
    guard rest.split_once("<!--mp:en-->") is Some((ja, rest)) else {
      out.write_string(rest.to_owned())
      return out.to_string()
    }
    guard rest.split_once("<!--mp:end-->") is Some((en, after)) else {
      out.write_string(rest.to_owned())
      return out.to_string()
    }
    out.write_string(
      if selected == "ja" {
        ja.to_owned()
      } else {
        en.to_owned()
      },
    )
    remaining = after.to_owned()
  }
  out.write_string(remaining)
  let rendered = out.to_string()
  for original in ["ja", "en"] {
    let prefix = "<!doctype html><html lang=\"" + original + "\">"
    if rendered.has_prefix(prefix) {
      return "<!doctype html><html lang=\"" +
        selected +
        "\">" +
        rendered[prefix.length():].to_owned()
    }
  }
  rendered
}

///|
fn admin_language_target(target : String) -> String {
  if target.any(c => c.is_control() || c == '\\' || !c.is_ascii()) ||
    target.contains("#") {
    return "/rooms"
  }
  let path = target.split("?").map(p => p.to_owned()).to_array()[0]
  if [
      "/", "/rooms", "/rooms/write", "/rooms/preview", "/rooms/build", "/rooms/publish",
      "/workflow", "/edit", "/media", "/media-replace", "/media-remove", "/references",
      "/reference-outputs", "/history", "/trash", "/trash-item", "/trash-post", "/revision-diff",
      "/revision", "/site-settings", "/recovery", "/authoring-recovery", "/publish",
    ].contains(path) {
    target
  } else {
    "/rooms"
  }
}

///|
fn admin_language_navigation(target : String) -> String {
  let destination = url_component(admin_language_target(target))
  "<nav aria-label=\"Language\"><span>Language / 言語</span><a lang=\"ja\" href=\"/language/ja?return=" +
  destination +
  "\">日本語</a><a lang=\"en\" href=\"/language/en?return=" +
  destination +
  "\">English</a><a href=\"/language/auto?return=" +
  destination +
  "\">Auto / 自動</a><small>" +
  admin_i18n(
    "編集中の内容は、切り替える前に保存してください。", "Save your edits before switching language.",
  ) +
  "</small></nav>"
}

///|
fn admin_language_response(request : AdminRequest) -> Bytes raise {
  if request.verb != "GET" {
    raise InvalidInput("Language preference requires GET navigation")
  }
  let parts = request.target.split("?").map(p => p.to_owned()).to_array()
  let preference = match parts[0] {
    "/language/ja" => "ja"
    "/language/en" => "en"
    "/language/auto" => "auto"
    _ => raise InvalidInput("Unknown language preference")
  }
  let target = if parts.length() == 1 {
    "/rooms"
  } else if parts.length() == 2 {
    let fields = admin_form(parts[1])
    if fields.length() != 1 {
      raise InvalidInput("Invalid language preference query")
    }
    admin_language_target(admin_field(fields, "return"))
  } else {
    raise InvalidInput("Invalid language preference query")
  }
  @utf8.encode(
    "HTTP/1.1 303 See Other\r\nContent-Length: 0\r\nConnection: close\r\nCache-Control: no-store\r\nVary: Accept-Language, Cookie\r\nLocation: " +
    target +
    "\r\nSet-Cookie: moonpress-language=" +
    preference +
    "; Path=/; HttpOnly; SameSite=Strict; Max-Age=" +
    (if preference == "auto" { "0" } else { "31536000" }) +
    "\r\n\r\n",
  )
}

///|
fn admin_title_ja(title : String) -> String {
  match title {
    "Revision comparison" => "記事の差分"
    "Article trash" => "記事のゴミ箱"
    "Inspect trashed article" => "ゴミ箱の記事を確認"
    "Review move to trash" => "ゴミ箱への移動を確認"
    "Article history" => "記事の履歴"
    "Inspect article revision" => "記事の過去の版を確認"
    "Posts" => "記事"
    "Media" => "画像とファイル"
    "Saved" => "保存しました"
    "Site settings" => "サイト設定"
    "Publish your site" => "サイトを公開する"
    "Full preview files built" => "プレビューを生成しました"
    "Production files built" => "公開用ファイルを生成しました"
    "Production changes inspected" => "公開用の変更計画"
    "From draft to published site" => "記事を書いて公開するまで"
    "Media storage ready" => "画像の保管場所を用意しました"
    "Media uploaded" => "ファイルを追加しました"
    "Media imported" => "ファイルを取り込みました"
    "Draft duplicated" => "下書きを複製しました"
    "Request rejected" =>
      "リクエストを受け付けられませんでした"
    "Not found" => "画面が見つかりません"
    "Production recovery inspection" => "公開用ファイルの復旧確認"
    "Recovery inspection blocked" => "復旧状態を確認できません"
    "Publishing preparation blocked" =>
      "公開の準備を確認できません"
    _ =>
      if title.has_prefix("Edit ") {
        "編集：" + title[5:].to_owned()
      } else {
        title
      }
  }
}
