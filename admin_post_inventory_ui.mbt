///|
fn admin_post_text(ja : String, en : String) -> String {
  ignore(ja)
  en
}

///|
fn admin_post_select(
  key : String,
  label : String,
  values : Array[(String, String)],
  fields : Map[String, String],
  fallback : String,
) -> String {
  let out = StringBuilder()
  out.write_string("<label>" + label + "<select name=\"" + key + "\">")
  for (value, text) in values {
    out.write_string(
      "<option value=\"" +
      value +
      "\"" +
      (if fields.get(key).unwrap_or(fallback) == value {
        " selected"
      } else {
        ""
      }) +
      ">" +
      text +
      "</option>",
    )
  }
  out.write_string("</select></label>")
  out.to_string()
}

///|
fn admin_post_filters(fields : Map[String, String]) -> String {
  let out = StringBuilder()
  out.write_string(
    "" +
    "<form method=\"get\" action=\"/\"><label>" +
    admin_post_text(
      "タイトル・ファイル名・タグを検索", "Search titles, filenames and tags",
    ) +
    "<input name=\"q\" maxlength=\"256\" value=\"" +
    escape_html(fields.get("q").unwrap_or("")) +
    "\"></label>",
  )
  out.write_string(
    admin_post_select(
      "state",
      admin_post_text("状態", "State"),
      [
        ("all", admin_post_text("すべて", "All posts")),
        ("draft", admin_post_text("下書き", "Drafts")),
        ("ready", admin_post_text("公開対象", "Ready for build")),
        ("unlisted", admin_post_text("一覧非掲載", "Unlisted")),
      ],
      fields,
      "all",
    ),
  )
  out.write_string(
    admin_post_select(
      "kind",
      admin_post_text("種別", "Type"),
      [
        ("all", admin_post_text("記事と固定ページ", "Posts and pages")),
        ("post", admin_post_text("記事", "Posts")),
        ("page", admin_post_text("固定ページ", "Pages")),
      ],
      fields,
      "all",
    ),
  )
  out.write_string(
    admin_post_select(
      "sort",
      admin_post_text("並び順", "Sort"),
      [
        ("source", admin_post_text("ファイル名順", "Filename order")),
        (
          "date_desc",
          admin_post_text("日付の新しい順", "Newest date first"),
        ),
        ("date_asc", admin_post_text("日付の古い順", "Oldest date first")),
      ],
      fields,
      "source",
    ),
  )
  out.write_string(
    "<button>" +
    admin_post_text("記事を探す", "Search posts") +
    "</button> <a href=\"/\">" +
    admin_post_text("条件を解除", "Clear filters") +
    "</a></form>" +
    "",
  )
  out.to_string()
}

///|
fn admin_post_pages(
  fields : Map[String, String],
  page : Int,
  pages : Int,
) -> String {
  let out = StringBuilder()
  out.write_string("<nav aria-label=\"Post pages\">")
  for
    (number, label) in [
      (page - 1, admin_post_text("前の記事", "Previous posts")),
      (page + 1, admin_post_text("次の記事", "Next posts")),
    ] {
    if number >= 1 && number <= pages {
      out.write_string(
        "<a rel=\"" +
        (if number < page { "prev" } else { "next" }) +
        "\" href=\"" +
        admin_post_url(fields, Map([("page", number.to_string())])) +
        "\">" +
        label +
        "</a> ",
      )
    }
  }
  out.write_string("</nav>")
  out.to_string()
}
