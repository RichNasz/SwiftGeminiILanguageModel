## Project Overview

SwiftGeminiILanguageModel is a Swift package that bridges Apple's FoundationModels framework to Google's Gemini API via the Interactions protocol. It provides a `LanguageModel` implementation so any app written against FoundationModels can use Gemini by swapping in `GeminiInteractionsLanguageModel` — no changes to session or generation code required.

**Package:** SwiftGeminiILanguageModel
**Platforms:** macOS 27.0+, iOS 27.0+, visionOS 27.0+, watchOS 27.0+
**Swift:** 6.2+

## Commands

```bash
swift build
swift test
```

Tests require macOS 27+ (Tahoe) with Xcode 27+.

## Architecture

Thin adapter — no business logic, no caching, no conversation management. Three translation layers:

- **RequestBuilder** — converts FoundationModels `LanguageModelExecutorGenerationRequest` to Gemini `InteractionRequest`
- **EventTranslator** — converts Gemini `AsyncThrowingStream<InteractionStreamEvent>` to FoundationModels `LanguageModelExecutorGenerationChannel` actions
- **ErrorMapper** — maps `GeminiInteractionsError` to `LanguageModelError` with an intermediate `GeminiILanguageModelError` layer

Key decision: capability flags are declared per-model at init time, not auto-detected. See `Spec/SwiftGeminiILanguageModel-WHY.md` for rationale.

## File Map

| File | Purpose |
|------|---------|
| `GeminiInteractionsLanguageModel.swift` | `LanguageModel` conformance, capability mapping |
| `GeminiInteractionsModel.swift` | Model identity + `Capabilities` flags |
| `GeminiInteractionsExecutor.swift` | `LanguageModelExecutor` conformance, `InteractionsClient` init |
| `RequestBuilder.swift` | Transcript-to-`InteractionRequest` translation |
| `EventTranslator.swift` | Stream event-to-channel action translation |
| `ErrorMapper.swift` | Error mapping + `GeminiILanguageModelError` definition |
| `AuthMode.swift` | `.apiKey` / `.proxied` enum |

## Dependencies

- **SwiftGeminiInteractions** — provides `InteractionsClient`, `InteractionRequest`, `InteractionStreamEvent`, streaming protocol

## Spec Files

Consult `Spec/` files for detailed design decisions:

| File | Covers |
|------|--------|
| `SwiftGeminiILanguageModel-WHAT.md` | Public API surface + acceptance criteria |
| `SwiftGeminiILanguageModel-HOW.md` | Implementation details |
| `SwiftGeminiILanguageModel-WHY.md` | Design rationale |
| `SwiftGeminiILanguageModel-Tests-WHAT/HOW/WHY.md` | Test strategy + implementation |

## Testing Strategy

- Unit tests only, no live API calls
- Swift Testing framework (`@Test`, `#expect`, `@Suite`)
- Four test suites: ErrorMapperTests, GeminiInteractionsModelTests, RequestBuilderTests, EventTranslatorTests
- 50 test cases total
