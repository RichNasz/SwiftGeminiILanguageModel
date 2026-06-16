---
status: accepted
---

# SwiftGeminiILanguageModel — WHAT

Public API surface and acceptance criteria.

## Public Types

### GeminiInteractionsLanguageModel

```swift
@available(macOS 27.0, iOS 27.0, visionOS 27.0, watchOS 27.0, *)
public struct GeminiInteractionsLanguageModel: LanguageModel, Sendable {
    public let model: GeminiInteractionsModel
    public let timeout: TimeInterval
    public let serviceTier: ServiceTier?

    public init(
        name: GeminiInteractionsModel,
        auth: AuthMode,
        timeout: TimeInterval = 60,
        serviceTier: ServiceTier? = nil
    )

    public var capabilities: LanguageModelCapabilities { get }
    public var executorConfiguration: GeminiInteractionsExecutor.Configuration { get }
}
```

**Acceptance criteria:**
- Conforms to `LanguageModel` protocol from FoundationModels
- `capabilities` maps model capability flags to `LanguageModelCapabilities`
- `executorConfiguration` produces a valid `GeminiInteractionsExecutor.Configuration`
- `.apiKey` auth produces empty custom headers; `.proxied` forwards the headers dictionary

### GeminiInteractionsModel

```swift
public struct GeminiInteractionsModel: Sendable, Hashable {
    public let id: String
    public let capabilities: Capabilities

    public init(id: String, capabilities: Capabilities)

    public struct Capabilities: Sendable, Hashable {
        public var samplingParams: Bool    // default: true
        public var reasoning: Bool         // default: false
        public var structuredOutput: Bool  // default: false
        public var imageInput: Bool        // default: false
        public var toolCalling: Bool       // default: true

        public init(
            samplingParams: Bool = true,
            reasoning: Bool = false,
            structuredOutput: Bool = false,
            imageInput: Bool = false,
            toolCalling: Bool = true
        )
    }
}
```

**Acceptance criteria:**
- Default capabilities: `samplingParams: true`, `toolCalling: true`, others `false`
- Hashable and Equatable
- `id` is a free-form string matching Gemini model identifiers

### AuthMode

```swift
public enum AuthMode: Sendable, Hashable {
    case apiKey(String)
    case proxied(headers: [String: String])
}
```

**Acceptance criteria:**
- `.apiKey` passes the key to `InteractionsClient`
- `.proxied` forwards all headers as custom headers on the executor configuration
- Both cases are Hashable and Sendable

### GeminiILanguageModelError

```swift
public enum GeminiILanguageModelError: Error, Sendable {
    case missingCredential
    case apiError(statusCode: Int, message: String)
    case streamError(String)
}
```

**Acceptance criteria:**
- `apiError` preserves HTTP status code and response body from Gemini API
- `streamError` wraps stream-level error messages
- Conforms to `Error` and `Sendable`

## Internal Types

### GeminiInteractionsExecutor

Conforms to `LanguageModelExecutor`. Creates an `InteractionsClient`, builds requests via `RequestBuilder`, streams via `EventTranslator`, and maps errors via `ErrorMapper`.

### RequestBuilder

Translates `LanguageModelExecutorGenerationRequest` into `InteractionRequest`:
- Instructions → `systemInstruction` (multiple entries joined with double newline)
- Prompts → user input steps with text and image content
- Responses → model output steps
- Tool calls → function call steps
- Tool outputs → function result steps
- Single text prompt with no instructions/tools → `.text` input shortcut
- Generation options: max tokens, tool calling mode, temperature, sampling mode, reasoning level
- Structured output: JSON schema response format
- Capability flags gate sampling, reasoning, and structured output parameters

### EventTranslator

Translates `AsyncThrowingStream<InteractionStreamEvent>` into `LanguageModelExecutorGenerationChannel`:
- Text deltas → response append text
- Function call names captured from `stepStart` events and forwarded with tool call arguments
- Function call arguments → tool calls with call ID and name tracking
- Thought summaries → reasoning entries (reuses entry ID across deltas)
- Interaction completed → usage statistics
- Error events → throw `GeminiILanguageModelError.streamError`
- Missing completion → fallback zero-token usage

### ErrorMapper

Maps `GeminiInteractionsError` to framework or library errors:
- `rateLimitExceeded` → `LanguageModelError.rateLimited`
- `httpError(413, _)` → `LanguageModelError.contextSizeExceeded`
- `networkError` → `LanguageModelError.timeout`
- Other `httpError` → `GeminiILanguageModelError.apiError`
- Non-Gemini errors pass through unmapped
