///|
/// Solver process budgets. Limits are checked before launching a subprocess.
pub(all) struct Limits {
  timeout_ms : Int32
  memory_mb : Int32
  max_query_bytes : Int32
  max_output_bytes : Int32
} derive(ToJson, @json.FromJson)

///|
pub extend Limits with ToJson::{to_json}

///|
pub extend Limits with @json.FromJson::{from_json}

///|
pub fn Limits::new(
  timeout_ms~ : Int32 = 60000,
  memory_mb~ : Int32 = 512,
  max_query_bytes~ : Int32 = 16777216,
  max_output_bytes~ : Int32 = 16777216,
) -> Limits {
  { timeout_ms, memory_mb, max_query_bytes, max_output_bytes, }
}
