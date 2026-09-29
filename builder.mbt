///|
pub fn compile_site(
  input : String,
  output : String,
  dry_run? : Bool = false,
  include_drafts? : Bool = false,
) -> BuildReport raise {
  let output = output.trim_end(chars="/").to_owned()
  if output.is_empty() {
    raise InvalidInput("Root output directory is not allowed")
  }
  let lock = lock_output(output, shared=dry_run)
  defer native_unlock_output(lock)
  let previous = load_previous(output)
  let plan = plan_site(input, previous, Some(output), include_drafts~)
  if !dry_run {
    apply_plan(output, plan)
  }
  plan.report
}

///|
pub fn build_site(input : String, output : String) -> Int raise {
  compile_site(input, output).pages
}

///|
pub fn check_site(
  input : String,
  include_drafts? : Bool = false,
) -> CheckReport raise {
  // No output path, prior manifest, temporary directory, or filesystem mutation.
  let plan = plan_site(input, Map([]), None, include_drafts~)
  { pages: plan.report.pages, outputs: plan.pending.length(), }
}
