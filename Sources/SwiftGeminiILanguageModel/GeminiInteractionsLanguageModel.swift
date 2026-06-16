import Foundation
import FoundationModels
import SwiftGeminiInteractions

@available(macOS 27.0, iOS 27.0, visionOS 27.0, watchOS 27.0, *)
public struct GeminiInteractionsLanguageModel: Sendable {
	public let model: GeminiInteractionsModel
	public let timeout: TimeInterval
	public let serviceTier: ServiceTier?
	let authMode: AuthMode

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

	public var capabilities: LanguageModelCapabilities {
		var caps: [LanguageModelCapabilities.Capability] = []
		if model.capabilities.toolCalling { caps.append(.toolCalling) }
		if model.capabilities.imageInput { caps.append(.vision) }
		if model.capabilities.reasoning { caps.append(.reasoning) }
		if model.capabilities.structuredOutput { caps.append(.guidedGeneration) }
		return LanguageModelCapabilities(capabilities: caps)
	}

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
