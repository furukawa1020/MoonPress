///|
priv struct AccessUser {
  id : Int
  login : String
  role : String
  active : Bool
  token_digest : String
} derive(ToJson, FromJson)

///|
pub(all) struct AccessPrincipal {
  id : Int
  login : String
  role : String
  active : Bool
} derive(ToJson)

///|
pub extend AccessPrincipal with ToJson::{to_json}

///|
pub(all) struct AccessReport {
  revision : String
  users : Array[AccessPrincipal]
} derive(ToJson)

///|
pub extend AccessReport with ToJson::{to_json}

///|
pub(all) struct AccessChange {
  report : AccessReport
  secret : String?
} derive(ToJson)

///|
pub extend AccessChange with ToJson::{to_json}

///|
priv struct AccessEvent {
  schema : Int
  sequence : Int
  previous : String
  action : String
  user : AccessUser
} derive(ToJson, FromJson)

///|
priv struct AccessState {
  revision : String
  sequence : Int
  users : Array[AccessUser]
}

///|
extern "C" fn access_private_file(file : NativeFile) -> Int = "moonpress_access_private_file"

///|
fn access_login(login : String) -> Unit raise {
  if login.length() < 3 ||
    login.length() > 64 ||
    !login.all(c => {
      c.is_ascii_alphabetic() ||
      c.is_ascii_digit() ||
      c == '_' ||
      c == '-' ||
      c == '.'
    }) ||
    login != login.to_lower() {
    raise InvalidInput(
      "Login must be 3-64 lowercase ASCII letters/digits or _-.",
    )
  }
}

///|
fn access_name(sequence : Int) -> String {
  let number = sequence.to_string()
  "0".repeat(8 - number.length()) + number + ".json"
}

///|
fn access_principal(user : AccessUser) -> AccessPrincipal {
  { id: user.id, login: user.login, role: user.role, active: user.active, }
}

///|
fn access_report(state : AccessState) -> AccessReport {
  { revision: state.revision, users: state.users.map(access_principal), }
}

///|
fn access_replay(directory : AuthoringDirectory) -> AccessState raise {
  let names = @fs.read_dir(directory.path).to_owned()
  if names.length() > 4096 {
    raise InvalidInput("Access log exceeds 4096 events")
  }
  names.sort()
  let users : Array[AccessUser] = []
  let mut revision = "absent"
  let mut sequence = 0
  for name in names {
    sequence += 1
    if name != access_name(sequence) {
      raise InvalidInput("Access log sequence/foreign file rejected")
    }
    let file = directory_read(directory.fd, authoring_name(name))
    if io_is_null(file) != 0 {
      raise InvalidInput("Cannot open access record")
    }
    if access_private_file(file) != 1 {
      io_close(file) |> ignore
      raise InvalidInput("Access record must be an owner-only regular file")
    }
    let bytes = read_opened_file(file, name, max_bytes=4096)
    let value = @json.parse(decode_text(bytes, name))
    strict_json_object(
      value,
      ["schema", "sequence", "previous", "action", "user"],
      "access event",
    )
    |> ignore
    let user_value = match value {
      Object(fields) => fields.get("user").unwrap_or(Json::null())
      _ => Json::null()
    }
    strict_json_object(
      user_value,
      ["id", "login", "role", "active", "token_digest"],
      "access user",
    )
    |> ignore
    let event : AccessEvent = @json.from_json(value)
    access_login(event.user.login)
    role_capabilities(event.user.role) |> ignore
    if event.schema != 1 ||
      event.sequence != sequence ||
      event.previous != revision ||
      !valid_digest(event.user.token_digest) {
      raise InvalidInput("Access event integrity rejected")
    }
    let id = event.user.id
    if event.action == "grant" {
      if id != users.length() + 1 ||
        users.length() >= 256 ||
        !event.user.active ||
        users.any(user => user.login == event.user.login) ||
        (users.is_empty() && event.user.role != "administrator") {
        raise InvalidInput("Invalid access grant")
      }
      users.push(event.user)
    } else {
      if id < 1 || id > users.length() {
        raise InvalidInput("Unknown access principal")
      }
      let old = users[id - 1]
      if old.login != event.user.login {
        raise InvalidInput("Access identity changed")
      }
      let valid = match event.action {
        "role" =>
          old.token_digest == event.user.token_digest &&
          old.active == event.user.active
        "rotate" =>
          old.role == event.user.role &&
          event.user.active &&
          old.token_digest != event.user.token_digest
        "revoke" =>
          old.role == event.user.role &&
          old.token_digest == event.user.token_digest &&
          old.active &&
          !event.user.active
        _ => false
      }
      if !valid {
        raise InvalidInput("Invalid access state transition")
      }
      if old.active &&
        old.role == "administrator" &&
        (!event.user.active || event.user.role != "administrator") &&
        users
        .filter(user => user.active && user.role == "administrator")
        .length() ==
        1 {
        raise InvalidInput("Cannot disable the last administrator")
      }
      users[id - 1] = event.user
    }
    revision = digest_bytes(bytes)
  }
  { revision, sequence, users, }
}

///|
fn access_open(input : String) -> AuthoringDirectory raise {
  let content = open_authoring_subdirectory(input, "content")
  defer directory_close(content.fd)
  let directory = open_authoring_subdirectory(input, ".moonpress-access")
  errdefer directory_close(directory.fd)
  require_same_authoring_site(content, directory)
  directory
}

///|
pub fn inspect_access(input : String) -> AccessReport raise {
  require_input_kind(input + "/content", 2)
  if path_kind(input + "/.moonpress-access") == 0 {
    return { revision: "absent", users: [], }
  }
  let directory = access_open(input)
  defer directory_close(directory.fd)
  directory.lock()
  access_report(access_replay(directory))
}

///|
fn access_token_digest(login : String, secret : String) -> String {
  digest_text("moonpress-application-v1\u0000" + login + "\u0000" + secret)
}

///|
fn access_equal(a : String, b : String) -> Bool {
  let a = @utf8.encode(a)
  let b = @utf8.encode(b)
  if a.length() != 64 || b.length() != 64 {
    return false
  }
  let mut difference = 0
  for i = 0; i < 64; i = i + 1 {
    difference = difference | (a[i].to_int() ^ b[i].to_int())
  }
  difference == 0
}

///|
pub fn authenticate_access(
  input : String,
  login : String,
  secret : String,
) -> AccessPrincipal? raise {
  if login.length() < 3 || login.length() > 64 || !valid_digest(secret) {
    return None
  }
  let directory = access_open(input)
  defer directory_close(directory.fd)
  directory.lock()
  let state = access_replay(directory)
  let digest = access_token_digest(login, secret)
  for user in state.users {
    if user.login == login &&
      user.active &&
      access_equal(user.token_digest, digest) {
      return Some(access_principal(user))
    }
  }
  None
}

///|
pub fn change_access(
  input : String,
  expected : String,
  action : String,
  login : String,
  role : String,
) -> AccessChange raise {
  access_login(login)
  if !["grant", "role", "rotate", "revoke"].contains(action) {
    raise InvalidInput("Invalid access action")
  }
  if action == "grant" || action == "role" {
    role_capabilities(role) |> ignore
  } else if role != "-" {
    raise InvalidInput("Rotation/revocation role argument must be -")
  }
  if path_kind(input + "/.moonpress-access") == 0 {
    if action != "grant" || expected != "absent" || role != "administrator" {
      raise InvalidInput(
        "First grant must create an administrator at absent revision",
      )
    }
    prepare_authoring_vault(input, ".moonpress-access") |> ignore
  }
  let directory = access_open(input)
  defer directory_close(directory.fd)
  directory.lock()
  let state = access_replay(directory)
  if state.revision != expected {
    raise InvalidInput("Access state changed; inspect again")
  }
  if state.sequence >= 4096 {
    raise InvalidInput("Access log is full")
  }
  let found = state.users.filter(user => user.login == login)
  let create = action == "grant"
  if (create && !found.is_empty()) || (!create && found.is_empty()) {
    raise InvalidInput("Principal already exists or is unknown")
  }
  let old : AccessUser = if create {
    {
      id: state.users.length() + 1,
      login,
      role,
      active: true,
      token_digest: "",
    }
  } else {
    found[0]
  }
  if create &&
    (
      state.users.length() >= 256 ||
      (state.users.is_empty() && role != "administrator")
    ) {
    raise InvalidInput("Invalid first principal or user limit")
  }
  if !create &&
    old.active &&
    old.role == "administrator" &&
    (action == "revoke" || (action == "role" && role != "administrator")) &&
    state.users
    .filter(user => user.active && user.role == "administrator")
    .length() ==
    1 {
    raise InvalidInput("Cannot disable the last administrator")
  }
  if action == "revoke" && !old.active {
    return { report: access_report(state), secret: None, }
  }
  if action == "role" && old.role == role {
    return { report: access_report(state), secret: None, }
  }
  let secret = if create || action == "rotate" {
    let bytes = Bytes::make(32, 0)
    if admin_random(bytes) != 0 {
      raise InvalidInput("Cannot obtain application secret randomness")
    }
    Some(@crypto.bytes_to_hex_string(bytes))
  } else {
    None
  }
  let user : AccessUser = {
    id: old.id,
    login,
    role: if action == "role" || create {
      role
    } else {
      old.role
    },
    active: if action == "revoke" {
      false
    } else if action == "rotate" {
      true
    } else {
      old.active
    },
    token_digest: match secret {
      Some(secret) => access_token_digest(login, secret)
      None => old.token_digest
    },
  }
  let event : AccessEvent = {
    schema: 1,
    sequence: state.sequence + 1,
    previous: state.revision,
    action,
    user,
  }
  let bytes = @utf8.encode(ToJson::to_json(event).stringify() + "\n")
  if bytes.length() > 4096 {
    raise InvalidInput("Access event too large")
  }
  directory.write_new(access_name(event.sequence), bytes, private_mode=true)
  { report: access_report(access_replay(directory)), secret, }
}
