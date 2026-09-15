///|
struct Request[C] {
  version : Int
  mode : String
  config : C
  property : @model_check.Property?
  justice : Array[Int]
  witnesses : Array[@model_check.Witness]
} derive(@json.FromJson)

///|
suberror ProtocolError {
  InvalidRequest(String)
} derive(Debug)

///|
/// Version 1 transport: one JSON argument in, {version: 1, result: ...} out.
/// Configuration is decoded into the model's own type before building a client.
pub fn[C : @json.FromJson, S : Eq, E, Snapshot : ToJson] dispatch(
  argument : String,
  make_client : (C) -> @model_check.Client[S, E, Snapshot] raise?,
) -> Json raise {
  let request : Request[C] = @json.from_json(@json.parse(argument[:]))
  guard request.version == 1 else {
    raise InvalidRequest("Unsupported protocol version")
  }
  guard request.mode == "export" || request.mode == "replay" else {
    raise InvalidRequest("Invalid mode")
  }
  let property = request.property
  if request.mode == "replay" && property is None {
    raise InvalidRequest("Replay requires a property")
  }
  let client = make_client(request.config)
  let result = if request.mode == "export" {
    client.model.to_json()
  } else {
    request.witnesses
    .map(w => client.accepts(property.unwrap(), w, justice=request.justice))
    .to_json()
  }
  { "version": 1, "result": result }
}

///|
/// CLI adapter. Failed decoding/exploration exits unsuccessfully with diagnostics.
pub fn[C : @json.FromJson, S : Eq, E, Snapshot : ToJson] serve(
  make_client : (C) -> @model_check.Client[S, E, Snapshot] raise?,
) -> Unit {
  let result = try {
    let argument = match @env.args().last() {
      Some(argument) => argument
      None => raise InvalidRequest("Missing JSON argument")
    }
    dispatch(argument, make_client)
  } catch {
    error => {
      println("Model driver failed: " + @debug.to_string(error))
      abort("Model driver failed")
    }
  }
  println(result.stringify())
}
