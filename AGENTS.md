# SwiftGeminiILanguageModel — AI Coding Reference

Machine-readable documentation for AI coding tools (Claude Code, Copilot, Cursor, etc.).

## Project Overview

SwiftGeminiILanguageModel is a Swift package providing a `LanguageModel` implementation that bridges Apple's FoundationModels to Google's Gemini API via the Interactions protocol. Drop in `GeminiInteractionsLanguageModel` and your existing FoundationModels code works with Gemini.

**Package:** SwiftGeminiILanguageModel
**Platforms:** macOS 27.0+, iOS 27.0+, visionOS 27.0+, watchOS 27.0+
**Swift:** 6.2+
**Public types:** `GeminiInteractionsLanguageModel`, `GeminiInteractionsModel`, `AuthMode`, `GeminiILanguageModelError`

## Basic Usage

### Pattern

```swift
import FoundationModels
import SwiftGeminiILanguageModel

let model = GeminiInteractionsModel(id: "gemini-2.5-flash", capabilities: .init())
let lm = GeminiInteractionsLanguageModel(
    name: model,
    auth: .apiKey("your-gemini-api-key")
)

let session = LanguageModelSession(model: lm)
let stream = session.streamResponse(to: "Explain Swift concurrency.")
for try await partial in stream {
    print(partial.content)
}
```

### Pitfalls

- **Capability flag mismatch** — Setting `reasoning: true` for a model that doesn't support reasoning causes API errors. Flags must match the model's actual abilities.
- **name: takes GeminiInteractionsModel** — The `name:` parameter label in the init takes a `GeminiInteractionsModel` struct, not a string model ID.
- **No baseURL** — Unlike OpenAI/Open Responses adapters, the Gemini endpoint is handled by `InteractionsClient` automatically. Don't look for a `baseURL` parameter.

## Auth Modes

### Pattern

**API key (Gemini API key):**

```swift
auth: .apiKey("your-gemini-api-key")
```

**Proxied (enterprise/local proxy):**

```swift
auth: .proxied(headers: ["X-Forwarded-User": "alice", "X-Internal-Token": "abc123"])
```

### Pitfalls

- **No Authorization with proxied** — `.proxied` sends no `Authorization` header; the proxy must handle auth. The headers dictionary is forwarded as custom headers.
- **No custom headers with apiKey** — `.apiKey` sends no custom headers; only `.proxied` forwards the provided headers dictionary.
- **API key goes to InteractionsClient** — The API key is passed to `InteractionsClient(apiKey:)`, not sent as a custom header.

## Capability Flags

### Pattern

```swift
let model = GeminiInteractionsModel(
    id: "gemini-2.5-pro",
    capabilities: .init(
        samplingParams: true,   // default: true
        reasoning: true,        // default: false
        structuredOutput: true, // default: false
        imageInput: true,       // default: false
        toolCalling: true       // default: true
    )
)
```

### Pitfalls

- **Flags gate request construction** — If `samplingParams: false`, temperature and topP are never sent even if set on generation options. The feature is silently omitted, not errored.
- **reasoning: false suppresses reasoning** — Reasoning effort is never included in the request, even if `ContextOptions(reasoningLevel:)` is set.
- **structuredOutput: false suppresses schemas** — JSON schema output format is never applied, even if `@Generable` types are used.
- **Defaults** — `samplingParams: true`, `toolCalling: true`, all others `false`.

## Error Handling

### Pattern

```swift
do {
    let result = try await session.respond(to: "Hello")
    print(result.content)
} catch let error as GeminiILanguageModelError {
    switch error {
    case .missingCredential:
        print("No API key configured")
    case .apiError(let code, let message):
        print("Gemini error \(code): \(message)")
    case .streamError(let detail):
        print("Stream failed: \(detail)")
    }
} catch {
    print("Framework error: \(error)")
}
```

### Pitfalls

- **Dual error types** — Some errors are mapped to `LanguageModelError` (rate limit, context size, timeout) for framework compatibility. `GeminiILanguageModelError.apiError` preserves Gemini-specific detail. Catch both types for full coverage.
- **Unmapped passthrough** — Unrecognized `GeminiInteractionsError` cases (like `.decodingError`) pass through unmapped. Don't assume all errors are `GeminiILanguageModelError` or `LanguageModelError`.

## Common Mistakes

1. **Missing capability flags** — Forgetting to set `reasoning: true` or `structuredOutput: true` for models that support these features. The features silently won't activate.
2. **Wrong platform** — Using this package without macOS 27+ / iOS 27+. FoundationModels is only available on these platforms.
3. **Unused model** — Constructing `GeminiInteractionsLanguageModel` but not passing it to `LanguageModelSession`. The model does nothing on its own.
4. **On-device assumptions** — Remote providers have different latency, token limits, and error patterns compared to on-device models.
