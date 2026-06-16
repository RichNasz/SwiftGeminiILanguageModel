# Getting Started

This guide progresses from basic streaming through every feature the library supports. Each section builds on the previous one.

## 1. Basic Streaming

The simplest usage — stream a text response from Gemini:

```swift
import FoundationModels
import SwiftGeminiILanguageModel

let model = GeminiInteractionsModel(id: "gemini-2.5-flash", capabilities: .init())
let lm = GeminiInteractionsLanguageModel(
    name: model,
    auth: .apiKey(ProcessInfo.processInfo.environment["GEMINI_API_KEY"]!)
)

let session = LanguageModelSession(model: lm)
let stream = session.streamResponse(to: "Explain Swift concurrency.")
for try await partial in stream {
    print(partial.content)
}
```

`GeminiInteractionsModel` declares the model's identity and capabilities. `GeminiInteractionsLanguageModel` wraps it into a `LanguageModel` that `LanguageModelSession` can use. From there, the session API is identical to on-device usage.

## 2. Auth Modes

**API Key** — for direct Gemini API access:

```swift
let lm = GeminiInteractionsLanguageModel(
    name: model,
    auth: .apiKey("your-gemini-api-key")
)
```

The API key is passed to the underlying `InteractionsClient` and sent as the authentication credential on every request.

**Proxied** — for enterprise setups where a reverse proxy handles auth upstream:

```swift
let lm = GeminiInteractionsLanguageModel(
    name: model,
    auth: .proxied(headers: ["X-Forwarded-User": "alice", "X-Internal-Token": "abc123"])
)
```

`.proxied` sends no `Authorization` header — the proxy handles it. The headers dictionary is forwarded as custom headers on every request.

## 3. Configuring Capability Flags

Capability flags tell the library what features the model supports. They gate request construction — if a flag is `false`, the corresponding parameter is never sent, even if set in generation options.

```swift
let model = GeminiInteractionsModel(
    id: "gemini-2.5-pro",
    capabilities: .init(
        samplingParams: true,
        reasoning: true,
        structuredOutput: true,
        imageInput: true,
        toolCalling: true
    )
)
```

| Flag | Default | What it gates |
|------|---------|---------------|
| `samplingParams` | `true` | Temperature, topP, sampling mode |
| `reasoning` | `false` | Extended thinking / reasoning effort |
| `structuredOutput` | `false` | JSON schema-constrained output |
| `imageInput` | `false` | Image attachments in prompts |
| `toolCalling` | `true` | Function calling / tool use |

If you set `reasoning: false` but the model supports reasoning, reasoning effort will silently never be sent. Always match flags to the model's actual abilities.

## 4. Tool Calling

Define a tool conforming to `Tool`, then pass it to the session. The model calls it automatically when relevant:

```swift
import FoundationModels
import SwiftGeminiILanguageModel

struct GetCurrentDate: Tool {
    let name = "get_current_date"
    let description = "Returns today's date as an ISO 8601 string."
    @Generable struct Arguments {}

    @concurrent func call(arguments: Arguments) async throws -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}

let model = GeminiInteractionsModel(id: "gemini-2.5-flash", capabilities: .init(toolCalling: true))
let lm = GeminiInteractionsLanguageModel(name: model, auth: .apiKey("key"))

let session = LanguageModelSession(model: lm, tools: [GetCurrentDate()])
let result = try await session.respond(to: "What day is it today?")
print(result.content)
```

Tool definitions are translated to Gemini's function calling format automatically. The library converts `GenerationSchema` tool parameters to Gemini's `JSONSchemaValue` via JSON round-trip.

## 5. Structured Output

Use `@Generable` to get typed, schema-constrained responses. The model must have `structuredOutput: true`:

```swift
import FoundationModels
import SwiftGeminiILanguageModel

@Generable
struct MovieRecommendation {
    @Guide(description: "The film title") var title: String
    @Guide(description: "Release year") var year: Int
    @Guide(description: "Why this film is recommended") var reason: String
}

let model = GeminiInteractionsModel(id: "gemini-2.5-flash", capabilities: .init(structuredOutput: true))
let lm = GeminiInteractionsLanguageModel(name: model, auth: .apiKey("key"))

let session = LanguageModelSession(model: lm)
let response = try await session.respond(to: "Recommend a classic sci-fi film.", generating: MovieRecommendation.self)
print(response.content.title)   // e.g. "Blade Runner"
print(response.content.year)    // e.g. 1982
print(response.content.reason)  // e.g. "A landmark in visual science fiction..."
```

The schema is sent to Gemini as a JSON schema response format with `application/json` MIME type.

## 6. Image Input

Send image attachments to vision-capable models with `imageInput: true`:

```swift
import FoundationModels
import SwiftGeminiILanguageModel

let model = GeminiInteractionsModel(id: "gemini-2.5-flash", capabilities: .init(imageInput: true))
let lm = GeminiInteractionsLanguageModel(name: model, auth: .apiKey("key"))

let session = LanguageModelSession(model: lm)
let imageAttachment = Attachment<ImageAttachmentContent>(cgImage)
let stream = session.streamResponse {
    imageAttachment
    "Describe what you see in this image."
}
for try await partial in stream {
    print(partial.content)
}
```

Images are JPEG-encoded at 0.8 quality and sent as base64 data. Remote image URLs are passed through without re-encoding.

## 7. Reasoning

Enable extended thinking for models with `reasoning: true`. Control the reasoning level via `ContextOptions`:

```swift
import FoundationModels
import SwiftGeminiILanguageModel

let model = GeminiInteractionsModel(id: "gemini-2.5-pro", capabilities: .init(reasoning: true))
let lm = GeminiInteractionsLanguageModel(name: model, auth: .apiKey("key"))

let session = LanguageModelSession(model: lm)
let options = ContextOptions(reasoningLevel: .deep)
let result = try await session.respond(to: "How many primes between 1 and 100?", contextOptions: options)
print(result.content)

// Access reasoning trace from transcript entries
let reasoning = result.transcriptEntries.compactMap { entry -> String? in
    guard case .reasoning(let r) = entry else { return nil }
    return r.description
}
print(reasoning.joined(separator: "\n\n"))
```

Reasoning levels map to Gemini's thinking levels: `.light` → low, `.moderate` → medium, `.deep` → high. Thinking summaries are always enabled so reasoning output is visible in the FoundationModels API.
