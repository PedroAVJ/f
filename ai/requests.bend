import Base
import ./wire_json.bend as J

# Public request data is typed. Json is confined to the internal wire parser.
type Role is Data:
  User{}
  Assistant{}
  System{}
type Message is Data:
  Message{role: Role, text: String}
type OpenRouterRequest is Data:
  OpenRouterRequest{model: String, messages: List<&2, Message>, max_tokens: U32, temperature: Maybe<&2, U32>}
type ResponsesRequest is Data:
  ResponsesRequest{model: String, input: String, instructions: String, max_output_tokens: U32, store: Bool}
type AnthropicRequest is Data:
  AnthropicRequest{model: String, messages: List<&2, Message>, system: String, max_tokens: U32}
type SpeechRequest is Data:
  SpeechRequest{voice_id: String, text: String, model_id: String}
type ClaudeRequest is Data:
  ClaudeRequest{prompt: String, resume: Maybe<&2, String>, model: Maybe<&2, String>}
type RequestError is Data:
  EmptyModel{}
  EmptyMessages{}
  InvalidLimit{}
  InvalidTemperature{}
  UnsupportedRole{}
  InvalidVoice{}
type HTTPRequest is Data:
  HTTPRequest{method: String, url: String, headers: String, body: String}

def role(r: Role) -> String:
  match r:
    case User{}: "user"
    case Assistant{}: "assistant"
    case System{}: "system"

def message(m: Message) -> String:
  match m:
    case Message{r, text}: "{\"role\":" ++ J.quote(role(r)) ++ ",\"content\":" ++ J.quote(text) ++ "}"

def messages(ms: List<&2, Message>) -> String:
  match ms:
    case Nil{}: ""
    case Con{m, Nil{}}: message(m)
    case Con{m, tail}: message(m) ++ "," ++ messages(tail)

def temperature(t: Maybe<&2, U32>) -> String:
  match t:
    case None{}: ""
    case Some{t}: ",\"temperature\":" ++ U32.show(t)

def valid_temperature(t: Maybe<&2, U32>) -> Bool:
  match t:
    case None{}: True{}
    case Some{t}: (t <= 2 : U32)

def openrouter_checked(empty: Bool, no_messages: Bool, no_limit: Bool, valid_temp: Bool, model: String, ms: List<&2, Message>, limit: U32, temp: Maybe<&2, U32>) -> Result<&2, &2, RequestError, HTTPRequest>:
  match empty no_messages no_limit valid_temp:
    case True{} _ _ _: Fail{EmptyModel{}}
    case _ True{} _ _: Fail{EmptyMessages{}}
    case _ _ True{} _: Fail{InvalidLimit{}}
    case _ _ _ False{}: Fail{InvalidTemperature{}}
    case _ _ _ _: Done{HTTPRequest{"POST", "https://openrouter.ai/api/v1/chat/completions", "{\"content-type\":\"application/json\"}", "{\"model\":" ++ J.quote(model) ++ ",\"messages\":[" ++ messages(ms) ++ "],\"max_tokens\":" ++ U32.show(limit) ++ temperature(temp) ++ ",\"stream\":true,\"stream_options\":{\"include_usage\":true}}"}}

def openrouter(+r: OpenRouterRequest) -> Result<&2, &2, RequestError, HTTPRequest>:
  match r:
    case OpenRouterRequest{+model, +ms, +limit, +temp}:
      openrouter_checked(String.is_empty(model), List.is_empty(&2, Message, ms), U32.is_eq(limit, 0), valid_temperature(temp), model, ms, limit, temp)

def boolean(b: Bool) -> String:
  match b:
    case True{}: "true"
    case False{}: "false"

def responses_checked(empty: Bool, no_limit: Bool, model: String, input: String, instructions: String, limit: U32, store: Bool) -> Result<&2, &2, RequestError, HTTPRequest>:
  match empty no_limit:
    case True{} _: Fail{EmptyModel{}}
    case _ True{}: Fail{InvalidLimit{}}
    case _ _: Done{HTTPRequest{"POST", "https://api.openai.com/v1/responses", "{\"content-type\":\"application/json\"}", "{\"model\":" ++ J.quote(model) ++ ",\"input\":" ++ J.quote(input) ++ ",\"instructions\":" ++ J.quote(instructions) ++ ",\"max_output_tokens\":" ++ U32.show(limit) ++ ",\"store\":" ++ boolean(store) ++ ",\"stream\":true}"}}

def responses(+r: ResponsesRequest) -> Result<&2, &2, RequestError, HTTPRequest>:
  match r:
    case ResponsesRequest{+model, input, instructions, +limit, store}:
      responses_checked(String.is_empty(model), U32.is_eq(limit, 0), model, input, instructions, limit, store)

def anthropic_roles(ms: List<&2, Message>) -> Bool:
  match ms:
    case Nil{}: True{}
    case Con{Message{System{}, text}, tail}: False{}
    case Con{m, tail}: anthropic_roles(tail)

def anthropic_checked(empty: Bool, no_messages: Bool, no_limit: Bool, valid_roles: Bool, model: String, ms: List<&2, Message>, system: String, limit: U32) -> Result<&2, &2, RequestError, HTTPRequest>:
  match empty no_messages no_limit valid_roles:
    case True{} _ _ _: Fail{EmptyModel{}}
    case _ True{} _ _: Fail{EmptyMessages{}}
    case _ _ True{} _: Fail{InvalidLimit{}}
    case _ _ _ False{}: Fail{UnsupportedRole{}}
    case _ _ _ _: Done{HTTPRequest{"POST", "https://api.anthropic.com/v1/messages", "{\"content-type\":\"application/json\",\"anthropic-version\":\"2023-06-01\"}", "{\"model\":" ++ J.quote(model) ++ ",\"messages\":[" ++ messages(ms) ++ "],\"system\":" ++ J.quote(system) ++ ",\"max_tokens\":" ++ U32.show(limit) ++ ",\"stream\":true}"}}

# Voice IDs are path segments; reject separators instead of interpolating URLs.
def anthropic(+r: AnthropicRequest) -> Result<&2, &2, RequestError, HTTPRequest>:
  match r:
    case AnthropicRequest{+model, +ms, system, +limit}:
      anthropic_checked(String.is_empty(model), List.is_empty(&2, Message, ms), U32.is_eq(limit, 0), anthropic_roles(ms), model, ms, system, limit)

def path_valid(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{Chr{+c}, tail}: (((c >= 48 : U32) && (c <= 57 : U32)) || ((c >= 65 : U32) && (c <= 90 : U32)) || ((c >= 97 : U32) && (c <= 122 : U32)) || U32.is_eq(c, 45) || U32.is_eq(c, 95)) && path_valid(tail)

def speech_checked(empty_model: Bool, empty_voice: Bool, valid: Bool, voice: String, text: String, model: String) -> Result<&2, &2, RequestError, HTTPRequest>:
  match empty_model empty_voice valid:
    case True{} _ _: Fail{EmptyModel{}}
    case _ True{} _: Fail{InvalidVoice{}}
    case _ _ False{}: Fail{InvalidVoice{}}
    case _ _ _: Done{HTTPRequest{"POST", "https://api.elevenlabs.io/v1/text-to-speech/" ++ voice ++ "/stream?output_format=mp3_44100_128", "{\"content-type\":\"application/json\",\"accept\":\"audio/mpeg\"}", "{\"text\":" ++ J.quote(text) ++ ",\"model_id\":" ++ J.quote(model) ++ "}"}}

def speech(r: SpeechRequest) -> Result<&2, &2, RequestError, HTTPRequest>:
  match r:
    case SpeechRequest{+voice, text, +model}:
      speech_checked(String.is_empty(model), String.is_empty(voice), path_valid(voice), voice, text, model)

def cli_option(name: String, value: Maybe<&2, String>) -> String:
  match value:
    case None{}: ""
    case Some{v}: "," ++ J.quote(name) ++ "," ++ J.quote(v)

# Caller chooses the executable and explicit execution permission at the host.
# Arguments are data, never shell text; official CLI owns authentication.
def cli_args(args: String, resume: Maybe<&2, String>, model: Maybe<&2, String>) -> String:
  args ++ cli_option("--resume", resume) ++ cli_option("--model", model) ++ "]"
def claude_arguments(r: ClaudeRequest) -> String:
  match r:
    case ClaudeRequest{prompt, resume, model}: cli_args("[\"-p\"," ++ J.quote(prompt) ++ ",\"--output-format\",\"stream-json\",\"--verbose\",\"--include-partial-messages\",\"--tools\",\"\"", resume, model)
