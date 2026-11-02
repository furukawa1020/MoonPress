///|
fn rest_embed_options(result : RestResponse) -> RestResponse {
  if result.code != 200 {
    return result
  }
  if result.value is Object(fields) {
    if fields.get("endpoints") is Some(Array(endpoints)) {
      for endpoint in endpoints {
        if endpoint is Object(endpoint) &&
          endpoint.get("methods") is Some(Array(methods)) &&
          methods.any(verb => {
            verb == "GET".to_json() || verb == "HEAD".to_json()
          }) &&
          endpoint.get("args") is Some(Object(args)) {
          args["_embed"] = {
            "type": ["boolean", "string", "array"].to_json(),
            "items": { "type": "string".to_json() },
            "maxItems": (16).to_json(),
            "description": "Public related resources in embed context; one level only.".to_json(),
          }
        }
      }
    }
    if fields.get("moonpress") is Some(Object(metadata)) {
      metadata["embedding"] = {
        "read_only": true.to_json(),
        "context": "embed".to_json(),
        "max_depth": (1).to_json(),
        "max_subrequests": (256).to_json(),
        "max_cache_bytes": (8388608).to_json(),
        "max_response_bytes": (16777216).to_json(),
      }
    }
  }
  result
}
