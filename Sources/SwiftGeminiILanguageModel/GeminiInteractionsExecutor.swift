import Foundation
import FoundationModels
import SwiftGeminiInteractions

/// Handles API communication with Gemini, translating FoundationModels requests to Gemini Interactions API calls.
///
/// Created automatically by the FoundationModels framework — consumers do not instantiate this directly.
@available(macOS 27.0, iOS 27.0, visionOS 27.0, watchOS 27.0, *)
public struct GeminiInteractionsExecutor: LanguageModelExecutor {
	public typealias Model = GeminiInteractionsLanguageModel

	/// All parameters needed to configure a Gemini API request.
	public struct Configuration: Hashable, Sendable {
		/// The model identity and capability flags.
		public let model: GeminiInteractionsModel
		/// Authentication mode for the Gemini API.
		public let authMode: AuthMode
		/// Request timeout in seconds.
		public let timeout: TimeInterval
		/// Optional Gemini service tier.
		public let serviceTier: ServiceTier?
		/// Custom HTTP headers forwarded on every request (populated from `.proxied` auth mode).
		public let customHeaders: [String: String]

		/// Creates an executor configuration.
		/// - Parameters:
		///   - model: The model identity and capability flags.
		///   - authMode: Authentication mode.
		///   - timeout: Request timeout in seconds.
		///   - serviceTier: Optional service tier. Defaults to `nil`.
		///   - customHeaders: Custom HTTP headers. Defaults to empty.
		public init(
			model: GeminiInteractionsModel,
			authMode: AuthMode,
			timeout: TimeInterval,
			serviceTier: ServiceTier? = nil,
			customHeaders: [String: String] = [:]
		) {
			self.model = model
			self.authMode = authMode
			self.timeout = timeout
			self.serviceTier = serviceTier
			self.customHeaders = customHeaders
		}
	}

	private let configuration: Configuration
	private let client: InteractionsClient

	/// Creates the executor and initializes the underlying `InteractionsClient`.
	/// - Parameter configuration: The configuration for this executor.
	public init(configuration: Configuration) throws {
		self.configuration = configuration
		let apiKey = switch configuration.authMode {
		case .apiKey(let key): key
		case .proxied: ""
		}
		self.client = InteractionsClient(apiKey: apiKey)
	}

	/// Translates a FoundationModels request to a Gemini API call, streams the response, and maps errors.
	public func respond(
		to request: LanguageModelExecutorGenerationRequest,
		model: GeminiInteractionsLanguageModel,
		streamingInto channel: LanguageModelExecutorGenerationChannel
	) async throws {
		do {
			let built = try RequestBuilder.build(
				from: request,
				model: configuration.model,
				serviceTier: configuration.serviceTier
			)
			let translator = EventTranslator()
			try await translator.translate(
				client.stream(built.request),
				into: channel
			)
		} catch {
			throw ErrorMapper.map(error)
		}
	}
}
