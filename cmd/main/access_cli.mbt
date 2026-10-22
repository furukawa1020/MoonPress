///|
fn is_access_command(command : String) -> Bool {
  ["access-role", "access-read", "access-change"].contains(command)
}

///|
fn access_required(command : String) -> Int {
  if command != "access-change" {
    3
  } else {
    7
  }
}

///|
fn access_usage(command : String) -> String {
  if command == "access-role" {
    "Usage: moonpress access-role <role> [--json]"
  } else if command == "access-read" {
    "Usage: moonpress access-read <site-directory> [--json]"
  } else {
    "Usage: moonpress access-change <site-directory> <expected-revision|absent> <grant|role|rotate|revoke> <login> <role|-> [--json]"
  }
}

///|
fn access_run(args : Array[String]) -> Json raise {
  if args[1] == "access-role" {
    {
      "role": args[2].to_json(),
      "capabilities": @lib.role_capabilities(args[2]).to_json(),
    }
  } else if args[1] == "access-read" {
    @lib.inspect_access(args[2]).to_json()
  } else {
    @lib.change_access(args[2], args[3], args[4], args[5], args[6]).to_json()
  }
}
