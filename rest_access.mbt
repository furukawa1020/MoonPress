///|
fn rest_with_access_users(
  input : String,
  authorization : String?,
  run : (AccessPrincipal, AuthoringDirectory, Array[AccessUser]) -> RestResponse raise,
) -> RestResponse raise {
  let (login, secret) = match authorization {
    Some(value) =>
      rest_basic(value) catch {
        _ => return rest_error(401, "rest_not_logged_in")
      }
    None => return rest_error(401, "rest_not_logged_in")
  }
  let vault = access_open(input) catch {
    _ => return rest_error(401, "rest_not_logged_in")
  }
  defer directory_close(vault.fd)
  vault.lock()
  let state = access_replay(vault) catch {
    _ => return rest_error(401, "rest_not_logged_in")
  }
  let users = state.users.filter(user => {
    user.login == login &&
    user.active &&
    access_equal(user.token_digest, access_token_digest(login, secret))
  })
  if users.length() != 1 {
    return rest_error(401, "rest_not_logged_in")
  }
  let principal = access_principal(users[0])
  let directory = open_authoring_subdirectory(input, "content")
  defer directory_close(directory.fd)
  require_same_authoring_site(directory, vault)
  directory.lock()
  run(principal, directory, state.users)
}

///|
fn rest_with_access(
  input : String,
  authorization : String?,
  run : (AccessPrincipal, AuthoringDirectory) -> RestResponse raise,
) -> RestResponse raise {
  rest_with_access_users(input, authorization, (principal, directory, _users) => {
    run(principal, directory)
  })
}
