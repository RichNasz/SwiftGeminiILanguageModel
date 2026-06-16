---
status: accepted
---

# SwiftGeminiILanguageModel Tests — WHAT

Test coverage and acceptance criteria.

## Overview

4 test suites, 50 test cases. Swift Testing framework (`@Test`, `#expect`, `@Suite`). Unit tests only — no live API calls.

## ErrorMapperTests (7 tests)

| Test | Verifies |
|------|----------|
| `rateLimitMapsToRateLimited` | `GeminiInteractionsError.rateLimitExceeded` → `LanguageModelError` |
| `httpError413MapsToContextSizeExceeded` | HTTP 413 with body → `LanguageModelError` |
| `httpError413EmptyBodyUsesDefault` | HTTP 413 with empty body → default message |
| `networkErrorMapsToTimeout` | Network error → `LanguageModelError.timeout` |
| `otherHttpErrorMapsToApiError` | HTTP 500 → `GeminiILanguageModelError.apiError` |
| `nonGeminiErrorPassesThrough` | Non-Gemini errors returned unchanged |
| `decodingErrorPassesThrough` | `GeminiInteractionsError.decodingError` returned unchanged |

## GeminiInteractionsModelTests (8 tests)

| Test | Verifies |
|------|----------|
| `defaultCapabilities` | Default flag values: sampling+toolCalling true, others false |
| `capabilityMappingAllEnabled` | All flags true → all `LanguageModelCapabilities` present |
| `capabilityMappingAllDisabled` | All flags false → no capabilities |
| `apiKeyAuthProducesEmptyHeaders` | `.apiKey` → empty custom headers |
| `proxiedAuthForwardsHeaders` | `.proxied` → headers forwarded |
| `serviceTierPassedThrough` | `.flex` tier set on configuration |
| `serviceTierNilByDefault` | No tier → nil |
| `modelEquality` | Same id + capabilities → equal + same hash |

## RequestBuilderTests (24 tests)

### Transcript Translation (8 tests)

| Test | Verifies |
|------|----------|
| `instructionsSetsSystemInstruction` | Single instruction → `systemInstruction` |
| `multipleInstructionsJoinedWithDoubleNewline` | Multiple instructions → joined with `\n\n` |
| `promptProducesUserInputStep` | Single prompt → `.text` input |
| `promptWithHistoryProducesSteps` | Multi-turn → `.steps` input with 3 entries |
| `responseProducesModelOutputStep` | Response → `.modelOutput` step with text |
| `emptyResponseSkipped` | Empty response text → step omitted |
| `toolOutputProducesFunctionResult` | Tool output → `.functionResult` with call ID |
| `emptyToolOutputFallsBackToEmptyJSON` | Empty tool output → `"{}"` |

### Generation Options (6 tests)

| Test | Verifies |
|------|----------|
| `maxTokensForwarded` | `maximumResponseTokens` → `maxOutputTokens` |
| `maxTokensNilNotSet` | No max tokens → nil |
| `toolCallingModeRequired` | `.required` → `.required` |
| `toolCallingModeDisallowed` | `.disallowed` → `.none` |
| `toolCallingModeAllowed` | `.allowed` → `.auto` |
| `toolCallingModeNilNotSet` | No mode → nil |

### Sampling (4 tests)

| Test | Verifies |
|------|----------|
| `samplingGreedySetsTemperatureZero` | `.greedy` → temperature 0 |
| `samplingNucleusSetsTopP` | `.random(probabilityThreshold:)` → topP |
| `samplingDisabledSkipsAll` | `samplingParams: false` → temperature and topP nil |
| `temperaturePassedThrough` | Explicit temperature forwarded |

### Reasoning (4 tests)

| Test | Verifies |
|------|----------|
| `reasoningLightMapsToLow` | `.light` → `.low` + summaries enabled |
| `reasoningModerateMapsToMedium` | `.moderate` → `.medium` |
| `reasoningDeepMapsToHigh` | `.deep` → `.high` |
| `reasoningDisabledSkips` | `reasoning: false` → thinkingLevel nil |

### Other (2 tests)

| Test | Verifies |
|------|----------|
| `modelIdPassedThrough` | Model ID set on `InteractionRequest.model` |
| `serviceTierFlexSet` / `serviceTierPrioritySet` / `serviceTierNilByDefault` | Service tier forwarded correctly (3 tests) |

## EventTranslatorTests (11 tests)

| Test | Verifies |
|------|----------|
| `textDeltaProcessedSuccessfully` | Text deltas → channel without error |
| `functionCallArgumentsProcessed` | Function call argument deltas processed |
| `multipleFunctionCallsTrackedByIndex` | Multiple concurrent function calls tracked by step index |
| `thoughtSummaryProcessed` | Thought summary → reasoning entry |
| `multipleThoughtSummariesReuseEntryID` | Multiple thought deltas reuse same entry ID |
| `interactionCompletedWithUsage` | Completion with usage → token counts forwarded |
| `interactionCompletedWithNilUsage` | Completion without usage → zero tokens |
| `noCompletionSendsFallbackUsage` | Missing completion → fallback zero-token usage |
| `errorEventThrowsStreamError` | Error event → throws `GeminiILanguageModelError.streamError` |
| `ignoredEventsProcessWithoutError` | Ignored events (created, status, stepStop) → no error |
| `fullConversationSequence` | Mixed text + function call + text → processes without error |
