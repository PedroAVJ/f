# Typed AI standard library. Pure native modules are imported here; foreign Runtime is separate.
import Base
import ./requests.bend as Requests
import ./codecs.bend as Codecs
import ./protocol.bend as Protocol
import ./speech.bend as Speech
import ./voice.bend as Voice
import ./transcription.bend as Transcription

type Provider is Data:
  OpenRouter{}
  OpenAI{}
  Anthropic{}
  ElevenLabs{}
  ClaudeCLI{}

# Legacy records remain for source compatibility; new native consumers use Requests.
type Role is Data:
  User{}
  Assistant{}
  System{}

type TextMessage is Data:
  TextMessage{role: Role, text: String}

type OpenRouterRequest is Data:
  OpenRouterRequest{model: String, messages: List<&2, TextMessage>, max_tokens: U32}

type OpenAIRequest is Data:
  OpenAIRequest{model: String, input: String, max_output_tokens: U32, store: Bool}

type AnthropicRequest is Data:
  AnthropicRequest{model: String, messages: List<&2, TextMessage>, max_tokens: U32}

type SpeechRequest is Data:
  SpeechRequest{voice_id: String, text: String, model_id: String, output_format: String}

type AgentRequest is Data:
  AgentRequest{prompt: String, resume_session: Maybe<&2, String>, allowed_tools: List<&2, String>}

type Lifecycle is Data:
  Idle{}
  Running{}
  Completed{}
  Cancelled{}
  Failed{}

def supports_text(provider: Provider) -> Bool:
  match provider:
    case ElevenLabs{}: False{}
    case _: True{}

def supports_speech(provider: Provider) -> Bool:
  match provider:
    case ElevenLabs{}: True{}
    case _: False{}
