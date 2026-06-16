---
status: accepted
---

# SwiftGeminiILanguageModel Tests — WHY

Test strategy rationale.

## Why Unit Tests Only

No integration tests, no live API calls. The library is a translation layer — it converts types from one protocol to another. Every translation rule can be verified by constructing an input, running the translator, and checking the output. Live API calls would test SwiftGeminiInteractions and the Gemini API, not this library's translation logic.

## Why Four Suites

The test suites map 1:1 to the library's four internal components:
- **ErrorMapper** — pure function, simplest to test
- **GeminiInteractionsModel** — data types and capability mapping
- **RequestBuilder** — the largest and most complex translation layer
- **EventTranslator** — async stream processing

This structure makes it obvious which component broke when a test fails.

## Why No Channel Output Inspection

`EventTranslatorTests` verifies that event sequences process without error but doesn't inspect the channel's output buffer. The channel is a FoundationModels framework type whose internal state isn't designed for test inspection.

**Tradeoff:** We verify that the translator handles all event types without crashing, but we don't assert exact channel contents. This is acceptable because:
1. The translator's logic is simple — each event maps to one channel action
2. If the mapping is wrong, the downstream `LanguageModelSession` will produce incorrect results, which will be caught by app-level testing
3. Attempting to inspect channel internals would couple tests to framework implementation details

## Why Capability-Gating Tests

Sampling and reasoning tests exist in two forms: "enabled" (flag true, parameters forwarded) and "disabled" (flag false, parameters omitted). This verifies the core design decision that capability flags gate request construction.

## Why Service Tier Tests

Service tier is a pass-through parameter, but it has three distinct states (`.flex`, `.priority`, `nil`) that must all work. The tests verify each state to prevent regressions if the `ServiceTier` enum gains new cases.

## What's Not Tested

- **Image encoding** — `cgImageToData` is a thin wrapper around `ImageIO`. Testing it would require constructing `CGImage` instances, which adds platform-specific complexity for minimal value.
- **JSON schema round-trip** — `jsonSchemaValueFromGenerationSchema` converts via JSON serialization. The conversion logic is exercised indirectly when structured output is tested at the app level.
- **`InteractionsClient` initialization** — the client is constructed with an API key string. Testing this would just verify that SwiftGeminiInteractions' init works, not our code.
- **End-to-end streaming** — requires a running Gemini API endpoint. Covered by manual testing and app-level integration tests.
