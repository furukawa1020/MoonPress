///|
fn admin_export(
  input : String,
  request : AdminRequest,
  body : Bytes,
  token : String,
) -> Bytes raise {
  if request.verb != "POST" || request.target != "/export-production" {
    raise InvalidInput("Production export requires POST")
  }
  let fields = admin_form(decode_text(body, "export form"))
  if fields.length() != 2 ||
    !fields.contains("token") ||
    !fields.contains("review_id") {
    raise InvalidInput("Export requires exactly token and review_id")
  }
  if admin_field(fields, "token") != token {
    raise InvalidInput("Invalid form token")
  }
  let snapshot = export_site(
    input,
    admin_production_output(input),
    admin_field(fields, "review_id"),
  )
  @utf8.encode(
    "HTTP/1.1 200 OK\r\nContent-Type: application/zip\r\nContent-Disposition: attachment; filename=\"moonpress-site.zip\"\r\nContent-Length: \{snapshot.content.length()}\r\nX-MoonPress-SHA256: " +
    snapshot.report.digest +
    "\r\nConnection: close\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nX-Frame-Options: DENY\r\nCross-Origin-Resource-Policy: same-origin\r\nReferrer-Policy: no-referrer\r\nContent-Security-Policy: default-src 'none'; sandbox allow-downloads; frame-ancestors 'none'; base-uri 'none'\r\n\r\n",
  ) +
  snapshot.content
}
