# SwiftGeminiILanguageModel

[![Swift 6.2+](https://img.shields.io/badge/Swift-6.2+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2027%20%7C%20iOS%2027%20%7C%20visionOS%2027%20%7C%20watchOS%2027-lightgrey.svg)](Package.swift)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-0.1.0-brightgreen.svg)](Package.swift)
[![Built with Claude Code](https://img.shields.io/badge/Built%20with-Claude%20Code-blueviolet?logo=claude)](https://claude.ai/code)

A drop-in `LanguageModel` implementation that connects Apple's FoundationModels to Google's Gemini API via the [Interactions protocol](https://ai.google.dev/gemini-api/docs/interactions) — swap in `GeminiInteractionsLanguageModel` and your existing FoundationModels code works with Gemini.

## Why

Apple's FoundationModels gives Swift apps a unified API for language models — sessions, streaming, tools, structured output — all through `LanguageModelSession`. But the on-device model is one provider among many. When you want to use Gemini, you shouldn't have to rewrite your app.

This package bridges FoundationModels to Google's Gemini API. It's an intentionally thin adapter — three translation layers (RequestBuilder, EventTranslator, ErrorMapper) convert requests in, events out, and errors between. No business logic, no caching, no opinions. Both FoundationModels and the Gemini API can evolve independently; only the affected translator needs updating.

## The Swap

**With on-device model:**

```swift
import FoundationModels

let session = LanguageModelSession()
let stream = session.streamResponse(to: "Explain Swift concurrency.")
for try await partial in stream {
    print(partial.content)
}
```

**With Gemini:**

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

The prompt, stream, and print are identical. Only the session init changes.

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/RichNasz/SwiftGeminiILanguageModel.git", branch: "main"),
]
```

Then add the dependency to your target:

```swift
.target(name: "YourApp", dependencies: [
    .product(name: "SwiftGeminiILanguageModel", package: "SwiftGeminiILanguageModel"),
]),
```

Requires macOS 27+, iOS 27+, visionOS 27+, or watchOS 27+ (Xcode 27+).

## API Overview

| Type | Purpose |
|------|---------|
| `GeminiInteractionsLanguageModel` | `LanguageModel` conformance — pass to `LanguageModelSession` |
| `GeminiInteractionsModel` | Model identity + capability flags |
| `AuthMode` | `.apiKey(String)` or `.proxied(headers:)` |
| `GeminiILanguageModelError` | Provider-specific error cases |

See [Spec/SwiftGeminiILanguageModel-WHAT.md](Spec/SwiftGeminiILanguageModel-WHAT.md) for full API details.

## Capability Flags

| Flag | Default | Enables |
|------|---------|---------|
| `samplingParams` | `true` | Temperature, topP, sampling mode sent in requests |
| `reasoning` | `false` | Extended thinking / reasoning effort |
| `structuredOutput` | `false` | JSON schema-constrained output |
| `imageInput` | `false` | Image attachments in prompts |
| `toolCalling` | `true` | Function calling / tool use |

## Next Steps

See [docs/getting-started.md](docs/getting-started.md) for the full progression from basic streaming through tool calling, structured output, image input, and reasoning.

## For AI Coding Tools

See [AGENTS.md](AGENTS.md) for machine-readable patterns and pitfalls when working with this library programmatically.

## License

[Apache License 2.0](LICENSE)
