///|
pub(all) struct BuildReport {
  pages : Int
  written : Int
  skipped : Int
  deleted : Int
  events : Array[String]
  changes : Array[BuildEvent]
} derive(ToJson)

///|
pub(all) struct CheckReport {
  pages : Int
  outputs : Int
} derive(ToJson)

///|
pub(all) struct BuildEvent {
  action : String
  path : String
  reason : String
} derive(ToJson)

///|
pub extend BuildEvent with ToJson::{to_json}

///|
pub extend BuildReport with ToJson::{to_json}

///|
pub extend CheckReport with ToJson::{to_json}
