---
status: accepted
---

# SwiftGeminiILanguageModel — WHY

Design rationale.

## Why a Thin Adapter

The library has no business logic, no caching, no conversation management. Three translation layers (RequestBuilder, EventTranslator, ErrorMapper) and nothing else.

**Rationale:** Both FoundationModels and the Gemini Interactions API evolve independently. A thin adapter minimizes the surface area that needs updating when either side changes. Business logic belongs in the app (via `LanguageModelSession`) or in the provider SDK (SwiftGeminiInteractions).

## Why the Gemini Interactions API

The Interactions API is Google's newest inference protocol — streaming-native, multi-turn with explicit steps, and designed for tool calling. It supersedes the older `generateContent` REST endpoint.

**Rationale:** SwiftGeminiInteractions already provides a typed Swift client for the Interactions API with streaming, tool execution, and agent orchestration. Building on it avoids reimplementing HTTP, SSE parsing, and auth. The `InteractionsClient` handles the wire protocol; this package translates between its types and FoundationModels types.

## Why Capability Flags Over Auto-Detection

Capabilities (`samplingParams`, `reasoning`, `structuredOutput`, `imageInput`, `toolCalling`) are declared per-model at init time, not auto-detected from the API.

**Rationale:**
1. **No latency** — Auto-detection would require an API call before the first real request, adding cold-start latency.
2. **No unreliable reporting** — Not all models accurately report their capabilities via API metadata. A model might accept reasoning parameters without actually supporting extended thinking.
3. **No silent misapplication** — If a flag is wrong, the developer set it explicitly. With auto-detection, a model metadata change could silently enable or disable features between app releases.
4. **One-time cost** — Setting capability flags is a one-time setup per model. The developer already knows which model they're using and what it supports.

**Tradeoff:** The developer must know the model's capabilities. Incorrect flags cause silent omission (flag set `false` when model supports the feature) or API errors (flag set `true` when model doesn't support it). This is an acceptable tradeoff — explicit declaration prevents runtime surprises.

## Why Dual Error Types

Errors are mapped to two types: `LanguageModelError` (framework-standard) and `GeminiILanguageModelError` (provider-specific).

**Rationale:**
- `LanguageModelError` cases (`.rateLimited`, `.contextSizeExceeded`, `.timeout`) let apps handle common failure modes generically, without knowing the provider.
- `GeminiILanguageModelError.apiError` preserves the HTTP status code and body for provider-specific diagnostics — essential for debugging but not something generic error handlers need.
- Unrecognized errors pass through unmapped, so new `GeminiInteractionsError` cases are never swallowed.

## Why Instructions Are Concatenated

Multiple `.instructions` transcript entries are joined with double-newline separators into a single `systemInstruction` string.

**Rationale:** The Gemini API accepts one system instruction. FoundationModels can produce multiple instruction entries (e.g., base instructions plus tool-use instructions). Concatenation preserves all instructions without losing any.

## Why the Input Format Optimization

Single text prompts with no instructions and no tools use `.text(string)` instead of `.steps([.userInput(...)])`.

**Rationale:** The Gemini Interactions API supports a simpler text-only input format. Using it for simple prompts avoids unnecessary step wrapping, which may affect how the model processes the input (some providers handle text and steps inputs differently).

## Why Thinking Summaries Are Always Enabled

When reasoning is activated (any thinking level set), `thinkingSummaries` is always set to `.enabled`.

**Rationale:** FoundationModels surfaces reasoning via `.reasoning` transcript entries. Without thinking summaries enabled, the model thinks but the app can't show what it thought about. Always enabling summaries ensures reasoning is visible in the FoundationModels API.

## Why JPEG at 0.8 Quality

Images are re-encoded as JPEG at 0.8 compression quality before being sent to the API.

**Rationale:** JPEG at 0.8 provides a good balance between image quality and payload size. The Gemini API accepts base64-encoded image data, so smaller payloads mean faster uploads. 0.8 quality is visually lossless for most use cases. Remote image URLs are passed through without re-encoding, since they don't need to be uploaded.

## Why Empty Tool Output Falls Back to `{}`

Empty tool output text is replaced with `"{}"` in the function result step.

**Rationale:** The Gemini API expects a non-empty result string for function results. An empty string may cause validation errors or be misinterpreted as a failure. `"{}"` is a valid JSON object that signals "no meaningful output" without triggering errors.
