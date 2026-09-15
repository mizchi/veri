///|
/// Solver process budgets. Limits are checked before launching a subprocess.
pub(all) struct Limits {
  timeout_ms : Int
  memory_mb : Int
  max_query_bytes : Int
  max_output_bytes : Int
} derive(ToJson, @json.FromJson)

///|
pub fn Limits::new(
  timeout_ms? : Int = 60000,
  memory_mb? : Int = 512,
  max_query_bytes? : Int = 16777216,
  max_output_bytes? : Int = 16777216,
) -> Limits {
  { timeout_ms, memory_mb, max_query_bytes, max_output_bytes, }
}
