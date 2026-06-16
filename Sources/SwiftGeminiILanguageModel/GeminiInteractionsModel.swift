import Foundation

/// Identifies a Gemini model and declares which features it supports.
///
/// Pass an instance to ``GeminiInteractionsLanguageModel/init(name:auth:timeout:serviceTier:)``
/// via the `name:` parameter.
///
/// ```swift
/// let model = GeminiInteractionsModel(
///     id: "gemini-2.5-flash",
///     capabilities: .init(reasoning: true, structuredOutput: true)
/// )
/// ```
public struct GeminiInteractionsModel: Sendable, Hashable {
	/// The Gemini model identifier (e.g. `"gemini-2.5-flash"`, `"gemini-2.5-pro"`).
	public let id: String

	/// Feature flags that gate which generation parameters are sent in API requests.
	public let capabilities: Capabilities

	/// Creates a model identity with the given identifier and capability flags.
	/// - Parameters:
	///   - id: A Gemini model identifier string.
	///   - capabilities: Feature flags declaring which features this model supports.
	public init(id: String, capabilities: Capabilities) {
		self.id = id
		self.capabilities = capabilities
	}

	/// Feature flags controlling which generation parameters are included in Gemini API requests.
	///
	/// When a flag is `false`, the corresponding parameter is silently omitted from the request
	/// even if set in generation options. Flags must match the model's actual abilities —
	/// setting a flag to `true` for an unsupported feature causes API errors.
	public struct Capabilities: Sendable, Hashable {
		/// Whether temperature, topP, and sampling mode are sent in requests. Defaults to `true`.
		public var samplingParams: Bool

		/// Whether extended thinking / reasoning effort is included. Defaults to `false`.
		public var reasoning: Bool

		/// Whether JSON schema-constrained output is applied. Defaults to `false`.
		public var structuredOutput: Bool

		/// Whether image attachments in prompts are processed. Defaults to `false`.
		public var imageInput: Bool

		/// Whether function calling / tool use is enabled. Defaults to `true`.
		public var toolCalling: Bool

		/// Creates capability flags with the specified feature settings.
		/// - Parameters:
		///   - samplingParams: Gate temperature, topP, and sampling mode. Defaults to `true`.
		///   - reasoning: Gate extended thinking. Defaults to `false`.
		///   - structuredOutput: Gate JSON schema output. Defaults to `false`.
		///   - imageInput: Gate image attachment processing. Defaults to `false`.
		///   - toolCalling: Gate function calling. Defaults to `true`.
		public init(
			samplingParams: Bool = true,
			reasoning: Bool = false,
			structuredOutput: Bool = false,
			imageInput: Bool = false,
			toolCalling: Bool = true
		) {
			self.samplingParams = samplingParams
			self.reasoning = reasoning
			self.structuredOutput = structuredOutput
			self.imageInput = imageInput
			self.toolCalling = toolCalling
		}
	}
}
