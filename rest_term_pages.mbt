///|
fn rest_term_page_bounds(
  total : Int,
  query : Map[String, String],
) -> (Int, Int, Int) raise {
  let size = rest_positive(query.get("per_page").unwrap_or("10"), 100)
  let page = rest_positive(query.get("page").unwrap_or("1"), 4096)
  rest_nonnegative(query.get("offset").unwrap_or("0"), 409600) |> ignore
  ((page - 1) * size, size, (total + size - 1) / size)
}
