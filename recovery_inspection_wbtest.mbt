///|
test "recovery inspection filesystem probe" {
  guard @env.get_env_var("MOONPRESS_RECOVERY_INSPECTION") is Some(output) else {
    return
  }
  let first = inspect_recovery(output)
  let second = inspect_recovery(output)
  assert_eq(first.to_json(), second.to_json())
  if @env.get_env_var("MOONPRESS_INSPECT_ONLY") is Some(_) {
    return
  }
  let actual = recover_output(output)
  assert_eq(first.to_json(), actual.to_json())
}
