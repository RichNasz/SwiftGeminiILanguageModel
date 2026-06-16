---
status: accepted
---

# SwiftGeminiILanguageModel — HOW

Implementation details.

## Architecture

Thin adapter bridging Apple's FoundationModels to Google's Gemini Interactions API via SwiftGeminiInteractions. Three translation layers, no business logic.

```
FoundationModels                    SwiftGeminiInteractions
     │                                       │
     ▼                                       ▼
LanguageModelSession ──▶ GeminiInteractionsLanguageModel
                              │
                    ┌─────────┼──────────┐
                    ▼         ▼          ▼
              RequestBuilder  EventTranslator  ErrorMapper
                    │         │          │
                    ▼         ▼          ▼
              InteractionRequest  StreamEvents  GeminiInteractionsError
```

## Request Pipeline

### 1. GeminiInteractionsExecutor.respond

Entry point. Creates `InteractionsClient` with the API key from `AuthMode`. Calls `RequestBuilder.build`, then streams via `EventTranslator.translate`. Errors caught and mapped via `ErrorMapper.map`.

### 2. RequestBuilder.build

**Transcript translation:**
- Iterates `request.transcript` entries sequentially
- `.instructions` → concatenated into `systemInstruction` (double-newline separated)
- `.prompt` → `Step.userInput` with text and image content
- `.response` → `Step.modelOutput` (empty text skipped)
- `.toolCalls` → `Step.functionCall` per call (with id, name, arguments JSON)
- `.toolOutput` → `Step.functionResult` (empty text → `"{}"`)
- `.reasoning` → skipped (reasoning is output-only)

**Input format optimization:**
Single text prompt with no instructions and no tools → `.text(string)` shortcut instead of `.steps([...])`.

**Tool definitions:**
Maps `enabledToolDefinitions` to `InteractionTool.function` with name, description, and JSON schema parameters.

**Generation config (capability-gated):**
- `maximumResponseTokens` → `maxOutputTokens`
- `toolCallingMode` → `ToolChoiceConfig` (.required, .none, .auto)
- Temperature and sampling mode → `temperature`, `topP` (gated by `samplingParams` flag)
- Reasoning level → `thinkingLevel` + `thinkingSummaries: .enabled` (gated by `reasoning` flag)
- Generation schema → `responseFormat` with JSON MIME type (gated by `structuredOutput` flag)

**JSON Schema conversion:**
`GenerationSchema` → `JSONSchemaValue` via JSON round-trip: encode to Data, deserialize to dictionary, recursively convert to typed `JSONSchemaValue` (object, array, string, integer, number, boolean).

**Image encoding:**
`CGImage` → JPEG data at 0.8 quality via `ImageIO`. Remote URLs passed as URI references without re-encoding.

### 3. EventTranslator.translate

**State tracking:**
- `activeFunctionCalls: [Int: String]` — maps step index to call ID
- `reasoningEntryID: String?` — reused across thought summary deltas
- `sentCompletion: Bool` — ensures at least one usage update is sent

**Event handling:**
- `.stepDelta(.text)` → channel `.response(.appendText)`
- `.stepDelta(.functionCallArguments)` → channel `.toolCalls(.toolCall(.appendArguments))`; first delta for a step index triggers an initial empty-name tool call event
- `.stepDelta(.thoughtSummary)` → channel `.reasoning(.appendText)`; first thought creates a new entry ID, subsequent reuse it
- `.stepStart("function_call")` → resets the active function call tracker for that index
- `.interactionCompleted` → channel `.response(.updateUsage)` with input/output/cached/reasoning token counts
- `.error` → throws `GeminiILanguageModelError.streamError`
- `.interactionCreated`, `.interactionStatusUpdate`, `.stepStop`, `.unknown` → ignored
- `.stepDelta(.image, .codeExecutionArguments, .googleSearchQuery, .urlContextUrl, .annotation, .unknown)` → ignored

**Completion fallback:**
If stream ends without `.interactionCompleted`, sends zero-token usage to satisfy channel expectations.

### 4. ErrorMapper.map

Sequential type check:
1. Cast to `GeminiInteractionsError` → call `mapGeminiError`
2. Otherwise → return original error

`mapGeminiError` switch:
- `.rateLimitExceeded` → `LanguageModelError.rateLimited` (nil reset date)
- `.httpError(413, body)` → `LanguageModelError.contextSizeExceeded` (empty body → default message)
- `.networkError` → `LanguageModelError.timeout`
- `.httpError(code, body)` → `GeminiILanguageModelError.apiError`
- Default (`.decodingError`, etc.) → return original `GeminiInteractionsError`

## Service Tier

Optional `ServiceTier` (`.flex`, `.priority`) passed through to `InteractionRequest.serviceTier`. Nil by default.
