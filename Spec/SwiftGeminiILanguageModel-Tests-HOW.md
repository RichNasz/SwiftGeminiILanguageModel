---
status: accepted
---

# SwiftGeminiILanguageModel Tests — HOW

Test implementation details.

## Framework

Swift Testing (`@Test`, `#expect`, `@Suite`, `Issue.record`). No XCTest.

## Test Suites

### ErrorMapperTests

Direct unit tests calling `ErrorMapper.map(error)` and checking the returned error type with `#expect(mapped is T)`. No mocking needed — `ErrorMapper` is a pure function.

### GeminiInteractionsModelTests

Tests construct `GeminiInteractionsModel` and `GeminiInteractionsLanguageModel` instances directly, then verify:
- Default capability flag values
- Capability mapping via `lm.capabilities.contains()`
- Executor configuration properties (`customHeaders`, `serviceTier`)
- `Hashable` conformance via `==` and `hashValue`

### RequestBuilderTests

Uses a private `buildRequest` helper that:
1. Creates a `Transcript` from provided entries
2. Wraps in `LanguageModelExecutorGenerationRequest` with configurable options, tools, schema, and context options
3. Calls `RequestBuilder.build` and returns the `InteractionRequest`

A private `steps(from:)` helper extracts steps from `.steps` input format.

Tests verify the `InteractionRequest` fields:
- `systemInstruction` content
- Input format (`.text` vs `.steps`)
- Step types and content (`.userInput`, `.modelOutput`, `.functionCall`, `.functionResult`)
- `generationConfig` properties (maxOutputTokens, toolChoice, temperature, topP, thinkingLevel, thinkingSummaries)
- `serviceTier`
- `model` ID

### EventTranslatorTests

Uses private helpers:
- `makeStream(events:)` — creates `AsyncThrowingStream<InteractionStreamEvent, Error>` from an array
- `translate(events:)` — creates `EventTranslator` with fixed entry IDs, creates a `LanguageModelExecutorGenerationChannel`, and calls `translate`
- `completedInteraction(usage:)` — creates an `Interaction` fixture with optional `Usage`

Tests verify that event sequences complete without throwing (success path) or throw the expected error type (error path). Channel output is not inspected — the tests verify that the translator processes events correctly without crashing or deadlocking.

## Dependencies

All tests use `@testable import SwiftGeminiILanguageModel` for internal type access. Tests import `FoundationModels` and `SwiftGeminiInteractions` for their public types used in request/event construction.

## Patterns

- **No live API calls** — all tests construct inputs programmatically
- **No mocking framework** — Swift Testing's built-in assertions suffice
- **Fixture helpers** — private helpers in each suite avoid repetitive setup
- **Entry ID stability** — `EventTranslatorTests` uses fixed UUIDs (`"resp-1"`, `"tc-1"`) for deterministic testing
