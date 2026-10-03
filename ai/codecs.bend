import Base
import ./wire_json.bend as J

type Provider is Data:
  OpenRouter{}
  Responses{}
  Anthropic{}
  Claude{}
type ErrorCode is Data:
  TransportError{}
  ProtocolError{}
  TruncatedStream{}
  ProviderError{}
  FrameLimit{}
  UnsupportedEvent{}
type Error is Data:
  Error{code: ErrorCode, status: U32, request_id: String}
type FinishReason is Data:
  Stop{}
  Length{}
  ToolCalls{}
  Other{}
type Usage is Data:
  Usage{input_tokens: U32, output_tokens: U32}
type ProviderEvent is Data:
  Delta{text: String}
  Finished{reason: FinishReason}
  DoneEvent{}
  UsageEvent{usage: Usage}
  Identity{id: String}
  Ignored{}

def protocol_error() -> Error:
  Error{ProtocolError{}, 0, ""}

def string(value: Maybe<&2, J.Json>) -> Result<&2, &2, Error, String>:
  match value:
    case Some{J.Text{text}}: Done{text}
    case _: Fail{protocol_error()}

def u32_read(value: Maybe<&2, U32>) -> Result<&2, &2, Error, U32>:
  match value:
    case Some{n}: Done{n}
    case None{}: Fail{protocol_error()}

def u32(value: Maybe<&2, J.Json>) -> Result<&2, &2, Error, U32>:
  match value:
    case Some{J.Number{text}}: u32_read(U32.read(text))
    case _: Fail{protocol_error()}

def usage_fields(input: Maybe<&2, J.Json>, output: Maybe<&2, J.Json>) -> Result<&2, &2, Error, ProviderEvent>:
  do Result<&2, &2, Error, ProviderEvent>:
    i : U32 <- u32(input)
    o : U32 <- u32(output)
    Done{UsageEvent{Usage{i, o}}}

def finish_reason(text: String) -> FinishReason:
  match text:
    case "stop": Stop{}
    case "end_turn": Stop{}
    case "stop_sequence": Stop{}
    case "length": Length{}
    case "max_tokens": Length{}
    case "tool_calls": ToolCalls{}
    case "tool_use": ToolCalls{}
    case _: Other{}

def finish(value: Maybe<&2, J.Json>) -> Result<&2, &2, Error, ProviderEvent>:
  match value:
    case Some{J.Text{text}}: Done{Finished{finish_reason(text)}}
    case _: Fail{protocol_error()}

def delta(value: Maybe<&2, J.Json>) -> Result<&2, &2, Error, ProviderEvent>:
  do Result<&2, &2, Error, ProviderEvent>:
    text : String <- string(value)
    Done{Delta{text}}

def router_delta(value: Maybe<&2, J.Json>) -> Result<&2, &2, Error, ProviderEvent>:
  match value:
    case Some{J.Text{text}}: Done{Delta{text}}
    case None{}: Done{Ignored{}}
    case Some{J.Null{}}: Done{Ignored{}}
    case _: Fail{protocol_error()}

def router_tools(value: Maybe<&2, J.Json>, content: Maybe<&2, J.Json>) -> Result<&2, &2, Error, ProviderEvent>:
  match value:
    case None{}: router_delta(content)
    case Some{J.Array{Nil{}}}: router_delta(content)
    case _: Fail{Error{UnsupportedEvent{}, 0, ""}}

def router_choice_delta(value: Maybe<&2, J.Json>) -> Result<&2, &2, Error, ProviderEvent>:
  match value:
    case Some{+d}: router_tools(J.get(d, "tool_calls"), J.get(d, "content"))
    case _: Fail{protocol_error()}

def router_finish(reason: Maybe<&2, J.Json>, d: Maybe<&2, J.Json>) -> Result<&2, &2, Error, ProviderEvent>:
  match reason:
    case Some{J.Text{reason}}: Done{Finished{finish_reason(reason)}}
    case _: router_choice_delta(d)

def router_choice(+choice: J.Json) -> Result<&2, &2, Error, ProviderEvent>:
  router_finish(J.get(choice, "finish_reason"), J.get(choice, "delta"))

def router_choices(value: Maybe<&2, J.Json>, usage: Maybe<&2, J.Json>) -> Result<&2, &2, Error, ProviderEvent>:
  match value usage:
    case Some{J.Array{Con{choice, Nil{}}}} _: router_choice(choice)
    case Some{J.Array{Nil{}}} Some{+u}: usage_fields(J.get(u, "prompt_tokens"), J.get(u, "completion_tokens"))
    case _ _: Fail{protocol_error()}

def router_fields(error: Maybe<&2, J.Json>, choices: Maybe<&2, J.Json>, usage: Maybe<&2, J.Json>) -> Result<&2, &2, Error, ProviderEvent>:
  match error:
    case None{}: router_choices(choices, usage)
    case _: Fail{Error{ProviderError{}, 0, ""}}

def router_json(+value: J.Json) -> Result<&2, &2, Error, ProviderEvent>:
  router_fields(J.get(value, "error"), J.get(value, "choices"), J.get(value, "usage"))

def responses_status(status: Maybe<&2, J.Json>) -> Result<&2, &2, Error, ProviderEvent>:
  match status:
    case Some{J.Text{"completed"}}: Done{DoneEvent{}}
    case _: Fail{protocol_error()}

def responses_complete(value: Maybe<&2, J.Json>) -> Result<&2, &2, Error, ProviderEvent>:
  match value:
    case Some{r}: responses_status(J.get(r, "status"))
    case _: Fail{protocol_error()}

def responses_fields(kind: String, +value: J.Json) -> Result<&2, &2, Error, ProviderEvent>:
  match kind:
    case "response.output_text.delta": delta(J.get(value, "delta"))
    case "response.completed": responses_complete(J.get(value, "response"))
    case "response.failed": Fail{Error{ProviderError{}, 0, ""}}
    case "response.incomplete": Fail{Error{TruncatedStream{}, 0, ""}}
    case "error": Fail{Error{ProviderError{}, 0, ""}}
    case "response.function_call_arguments.delta": Fail{Error{UnsupportedEvent{}, 0, ""}}
    case "response.created": Done{Ignored{}}
    case "response.in_progress": Done{Ignored{}}
    case "response.output_text.done": Done{Ignored{}}
    case "response.content_part.added": Done{Ignored{}}
    case "response.content_part.done": Done{Ignored{}}
    case "response.output_item.added": Done{Ignored{}}
    case "response.output_item.done": Done{Ignored{}}
    case _: Fail{Error{UnsupportedEvent{}, 0, ""}}

def responses_json(+value: J.Json) -> Result<&2, &2, Error, ProviderEvent>:
  do Result<&2, &2, Error, ProviderEvent>:
    kind : String <- string(J.get(value, "type"))
    responses_fields(kind, value)

def anthropic_delta(kind: String, +value: J.Json) -> Result<&2, &2, Error, ProviderEvent>:
  match kind:
    case "text_delta": delta(J.get(value, "text"))
    case _: Fail{Error{UnsupportedEvent{}, 0, ""}}

def anthropic_delta_json(+value: J.Json) -> Result<&2, &2, Error, ProviderEvent>:
  do Result<&2, &2, Error, ProviderEvent>:
    kind : String <- string(J.get(value, "type"))
    anthropic_delta(kind, value)

def anthropic_block(value: Maybe<&2, J.Json>) -> Result<&2, &2, Error, ProviderEvent>:
  match value:
    case Some{+d}: anthropic_delta_json(d)
    case _: Fail{protocol_error()}

def anthropic_stop(value: Maybe<&2, J.Json>) -> Result<&2, &2, Error, ProviderEvent>:
  match value:
    case Some{+d}: finish(J.get(d, "stop_reason"))
    case _: Fail{protocol_error()}

def anthropic_start_kind(kind: Maybe<&2, J.Json>) -> Result<&2, &2, Error, ProviderEvent>:
  match kind:
    case Some{J.Text{"text"}}: Done{Ignored{}}
    case _: Fail{Error{UnsupportedEvent{}, 0, ""}}

def anthropic_start(value: Maybe<&2, J.Json>) -> Result<&2, &2, Error, ProviderEvent>:
  match value:
    case Some{block}: anthropic_start_kind(J.get(block, "type"))
    case _: Fail{protocol_error()}

def anthropic_fields(kind: String, +value: J.Json) -> Result<&2, &2, Error, ProviderEvent>:
  match kind:
    case "content_block_delta": anthropic_block(J.get(value, "delta"))
    case "message_delta": anthropic_stop(J.get(value, "delta"))
    case "message_stop": Done{DoneEvent{}}
    case "error": Fail{Error{ProviderError{}, 0, ""}}
    case "ping": Done{Ignored{}}
    case "message_start": Done{Ignored{}}
    case "content_block_start": anthropic_start(J.get(value, "content_block"))
    case "content_block_stop": Done{Ignored{}}
    case _: Fail{Error{UnsupportedEvent{}, 0, ""}}

def anthropic_json(+value: J.Json) -> Result<&2, &2, Error, ProviderEvent>:
  do Result<&2, &2, Error, ProviderEvent>:
    kind : String <- string(J.get(value, "type"))
    anthropic_fields(kind, value)

def claude_result(failed: Maybe<&2, J.Json>, subtype: Maybe<&2, J.Json>) -> Result<&2, &2, Error, ProviderEvent>:
  match failed subtype:
    case Some{J.Boolean{False{}}} Some{J.Text{"success"}}: Done{DoneEvent{}}
    case _ _: Fail{Error{ProviderError{}, 0, ""}}

def claude_stream_result(result: Result<&2, &2, Error, ProviderEvent>) -> Result<&2, &2, Error, ProviderEvent>:
  match result:
    case Done{DoneEvent{}}: Done{Ignored{}}
    case _: result

def claude_stream(value: Maybe<&2, J.Json>) -> Result<&2, &2, Error, ProviderEvent>:
  match value:
    case Some{d}: claude_stream_result(anthropic_json(d))
    case _: Fail{protocol_error()}

def claude_fields(kind: String, +value: J.Json) -> Result<&2, &2, Error, ProviderEvent>:
  match kind:
    case "stream_event": claude_stream(J.get(value, "event"))
    case "result": claude_result(J.get(value, "is_error"), J.get(value, "subtype"))
    case "system": Done{Ignored{}}
    case "assistant": Done{Ignored{}}
    case _: Fail{Error{UnsupportedEvent{}, 0, ""}}

def claude_json(+value: J.Json) -> Result<&2, &2, Error, ProviderEvent>:
  do Result<&2, &2, Error, ProviderEvent>:
    kind : String <- string(J.get(value, "type"))
    claude_fields(kind, value)

def parsed(provider: Provider, result: Result<&1, &1, String, J.Json>) -> Result<&2, &2, Error, ProviderEvent>:
  match provider result:
    case _ Fail{message}: Fail{protocol_error()}
    case OpenRouter{} Done{value}: router_json(value)
    case Responses{} Done{value}: responses_json(value)
    case Anthropic{} Done{value}: anthropic_json(value)
    case Claude{} Done{value}: claude_json(value)

def decode(provider: Provider, +data: String) -> Result<&2, &2, Error, ProviderEvent>:
  match provider data:
    case OpenRouter{} "[DONE]": Done{DoneEvent{}}
    case +p _: parsed(p, J.read(data))
