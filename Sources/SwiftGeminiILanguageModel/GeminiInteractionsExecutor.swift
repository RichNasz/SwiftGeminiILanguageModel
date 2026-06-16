import Foundation
import FoundationModels
import SwiftGeminiInteractions

@available(macOS 27.0, iOS 27.0, visionOS 27.0, watchOS 27.0, *)
public struct GeminiInteractionsExecutor: LanguageModelExecutor {
	public typealias Model = GeminiInteractionsLanguageModel

	public struct Configuration: Hashable, Sendable {
		public let model: GeminiInteractionsModel
		public let authMode: AuthMode
		public let timeout: TimeInterval
		public let serviceTier: ServiceTier?
		public let customHeaders: [String: String]

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

	public init(configuration: Configuration) throws {
		self.configuration = configuration
		let apiKey = switch configuration.authMode {
		case .apiKey(let key): key
		case .proxied: ""
		}
		self.client = InteractionsClient(apiKey: apiKey)
	}

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
