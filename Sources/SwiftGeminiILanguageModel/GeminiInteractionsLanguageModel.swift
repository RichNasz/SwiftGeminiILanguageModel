import Foundation
import FoundationModels
import SwiftGeminiInteractions

/// A `LanguageModel` implementation that connects Apple's FoundationModels to Google's Gemini API.
///
/// Pass an instance to `LanguageModelSession(model:)` to use Gemini as the backend.
/// All existing FoundationModels code (streaming, tools, structured output) works unchanged.
///
/// ```swift
/// let model = GeminiInteractionsModel(id: "gemini-2.5-flash", capabilities: .init())
/// let lm = GeminiInteractionsLanguageModel(
///     name: model,
///     auth: .apiKey("your-gemini-api-key")
/// )
/// let session = LanguageModelSession(model: lm)
/// ```
///
/// - Important: The `name:` parameter takes a ``GeminiInteractionsModel`` struct, not a string.
@available(macOS 27.0, iOS 27.0, visionOS 27.0, watchOS 27.0, *)
public struct GeminiInteractionsLanguageModel: Sendable {
	/// The model identity and capability flags.
	public let model: GeminiInteractionsModel

	/// Request timeout in seconds. Defaults to 60.
	public let timeout: TimeInterval

	/// Optional Gemini service tier. `nil` uses the API's default.
	public let serviceTier: ServiceTier?

	let authMode: AuthMode

	/// Creates a Gemini-backed language model.
	/// - Parameters:
	///   - name: The model identity and capability flags. This is a ``GeminiInteractionsModel``, not a string.
	///   - auth: Authentication mode — `.apiKey("key")` or `.proxied(headers:)`.
	///   - timeout: Request timeout in seconds. Defaults to `60`.
	///   - serviceTier: Optional Gemini service tier. Defaults to `nil`.
	public init(
		name: GeminiInteractionsModel,
		auth: AuthMode,
		timeout: TimeInterval = 60,
		serviceTier: ServiceTier? = nil
	) {
		self.model = name
		self.authMode = auth
		self.timeout = timeout
		self.serviceTier = serviceTier
	}
}

@available(macOS 27.0, iOS 27.0, visionOS 27.0, watchOS 27.0, *)
extension GeminiInteractionsLanguageModel: LanguageModel {
	public typealias Executor = GeminiInteractionsExecutor

	/// The model's capabilities mapped to FoundationModels capability flags.
	public var capabilities: LanguageModelCapabilities {
		var caps: [LanguageModelCapabilities.Capability] = []
		if model.capabilities.toolCalling { caps.append(.toolCalling) }
		if model.capabilities.imageInput { caps.append(.vision) }
		if model.capabilities.reasoning { caps.append(.reasoning) }
		if model.capabilities.structuredOutput { caps.append(.guidedGeneration) }
		return LanguageModelCapabilities(capabilities: caps)
	}

	/// Configuration for the executor. Created automatically by the framework.
	public var executorConfiguration: GeminiInteractionsExecutor.Configuration {
		let headers: [String: String] = switch authMode {
		case .apiKey: [:]
		case .proxied(let h): h
		}
		return .init(
			model: model,
			authMode: authMode,
			timeout: timeout,
			serviceTier: serviceTier,
			customHeaders: headers
		)
	}
}
