# SwiftGeminiILanguageModel — AI Coding Reference

Machine-readable documentation for AI coding tools (Claude Code, Copilot, Cursor, etc.).

## Project Overview

SwiftGeminiILanguageModel is a Swift package providing a `LanguageModel` implementation that bridges Apple's FoundationModels to Google's Gemini API via the Interactions protocol. Drop in `GeminiInteractionsLanguageModel` and your existing FoundationModels code works with Gemini.

**Package:** SwiftGeminiILanguageModel
**Platforms:** macOS 27.0+, iOS 27.0+, visionOS 27.0+, watchOS 27.0+
**Swift:** 6.2+
**Public types:** `GeminiInteractionsLanguageModel`, `GeminiInteractionsModel`, `AuthMode`, `GeminiILanguageModelError`

## Installation

### Pattern

**Package.swift:**

```swift
dependencies: [
    .package(url: "https://github.com/RichNasz/SwiftGeminiILanguageModel.git", branch: "main"),
]
```

Add to target:

```swift
.target(name: "YourApp", dependencies: [
    .product(name: "SwiftGeminiILanguageModel", package: "SwiftGeminiILanguageModel"),
]),
```

**Xcode project:**
Add `https://github.com/RichNasz/SwiftGeminiILanguageModel.git` as a Swift Package dependency with branch rule `main`.

### Pitfalls

- **Requires macOS 27+ / iOS 27+** — FoundationModels is only available on these platforms. Earlier deployment targets will fail to build.
- **Branch-based dependency** — Uses `branch: "main"`, not a version tag. Package resolution may pull different code on different days.

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

## Quick Reference

Minimal complete example — copy and adapt:

```swift
import FoundationModels
import SwiftGeminiILanguageModel

// 1. Model identity + capabilities
let model = GeminiInteractionsModel(
    id: "gemini-2.5-flash",           // Gemini model identifier
    capabilities: .init(               // defaults: samplingParams=true, toolCalling=true, others=false
        reasoning: false,              // set true for models with thinking support
        structuredOutput: false,       // set true for @Generable typed responses
        imageInput: false              // set true for vision models
    )
)

// 2. Language model with auth
let lm = GeminiInteractionsLanguageModel(
    name: model,                       // parameter label is "name:", type is GeminiInteractionsModel
    auth: .apiKey("GEMINI_API_KEY"),   // or .proxied(headers: [...])
    timeout: 60,                       // seconds, default 60
    serviceTier: nil                   // .flex, .standard, .priority, or nil
)

// 3. Use with LanguageModelSession — identical to on-device usage
let session = LanguageModelSession(model: lm)
let stream = session.streamResponse(to: "Hello")
for try await partial in stream {
    print(partial.content)
}
```
