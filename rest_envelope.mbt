///|
fn rest_envelope(result : RestResponse, allowed : String?) -> RestResponse {
  let headers : Map[String, Json] = Map([])
  if result.total is Some(total) {
    headers["X-WP-Total"] = total.to_json()
  }
  if result.pages is Some(pages) {
    headers["X-WP-TotalPages"] = pages.to_json()
  }
  if result.location is Some(location) {
    headers["Location"] = location.to_json()
  }
  if result.etag is Some(etag) {
    headers["ETag"] = ("\"" + etag + "\"").to_json()
  }
  if allowed is Some(verbs) {
    headers["Allow"] = verbs.to_json()
  }
  rest_ok({
    "body": result.value,
    "status": result.code.to_json(),
    "headers": Json::object(headers),
  })
}
