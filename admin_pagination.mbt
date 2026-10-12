///|
fn admin_page_number(value : String) -> Int raise {
  if value.is_empty() || value.length() > 8 {
    raise InvalidInput("Page must be a positive decimal integer")
  }
  let mut page = 0
  for ch in value {
    if ch < '0' || ch > '9' {
      raise InvalidInput("Page must be a positive decimal integer")
    }
    page = page * 10 + ch.to_int() - 48
  }
  if page == 0 {
    raise InvalidInput("Page must be a positive decimal integer")
  }
  page
}

///|
fn admin_page_bounds(total : Int, page : Int) -> (Int, Int, Int) raise {
  if total < 0 {
    raise InvalidInput("Item count must be nonnegative")
  }
  let pages = if total == 0 { 1 } else { (total - 1) / 20 + 1 }
  if page < 1 || page > pages {
    raise InvalidInput("Page exceeds available pages")
  }
  let start = (page - 1) * 20
  let end = if total - start < 20 { total } else { start + 20 }
  (start, end, pages)
}
