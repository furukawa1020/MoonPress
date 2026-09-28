///|
test "exclusive output lock rejects aliases and shared readers" {
  let fd = lock_output(".moonpress-lock-test-output", shared=false)
  defer native_unlock_output(fd)
  for shared in [false, true] {
    let rejected = try {
      let other = lock_output("./.moonpress-lock-test-output", shared~)
      native_unlock_output(other)
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
test "shared explain locks coexist and exclude writers" {
  let first = lock_output(".moonpress-lock-test-output", shared=true)
  defer native_unlock_output(first)
  let second = lock_output("./.moonpress-lock-test-output", shared=true)
  defer native_unlock_output(second)
  let rejected = try {
    let other = lock_output(".moonpress-lock-test-output", shared=false)
    native_unlock_output(other)
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "compile releases lock after raised errors in same process" {
  let rejected = try {
    compile_site(".moonpress-missing-source", ".moonpress-lock-test-output")
    |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  let fd = lock_output(".moonpress-lock-test-output", shared=false)
  defer native_unlock_output(fd)
}
