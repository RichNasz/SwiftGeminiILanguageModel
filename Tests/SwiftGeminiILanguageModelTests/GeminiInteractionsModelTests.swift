import Testing
import Foundation
import FoundationModels
@testable import SwiftGeminiILanguageModel

@Suite("GeminiInteractionsModel")
struct GeminiInteractionsModelTests {

	@Test func defaultCapabilities() {
		let caps = GeminiInteractionsModel.Capabilities()
		#expect(caps.samplingParams == true)
		#expect(caps.toolCalling == true)
		#expect(caps.reasoning == false)
		#expect(caps.structuredOutput == false)
		#expect(caps.imageInput == false)
	}

	@Test func capabilityMappingAllEnabled() {
		let model = GeminiInteractionsModel(
			id: "gemini-2.5-flash",
			capabilities: .init(
				samplingParams: true,
				reasoning: true,
				structuredOutput: true,
				imageInput: true,
				toolCalling: true
			)
		)
		let lm = GeminiInteractionsLanguageModel(
			name: model,
			auth: .apiKey("key")
		)
		let caps = lm.capabilities
		#expect(caps.contains(.toolCalling))
		#expect(caps.contains(.vision))
		#expect(caps.contains(.reasoning))
		#expect(caps.contains(.guidedGeneration))
	}

	@Test func capabilityMappingAllDisabled() {
		let model = GeminiInteractionsModel(
			id: "gemini-2.5-flash",
			capabilities: .init(
				samplingParams: false,
				reasoning: false,
				structuredOutput: false,
				imageInput: false,
				toolCalling: false
			)
		)
		let lm = GeminiInteractionsLanguageModel(
			name: model,
			auth: .apiKey("key")
		)
		let caps = lm.capabilities
		#expect(!caps.contains(.toolCalling))
		#expect(!caps.contains(.vision))
		#expect(!caps.contains(.reasoning))
		#expect(!caps.contains(.guidedGeneration))
	}

	@Test func apiKeyAuthProducesEmptyHeaders() {
		let lm = GeminiInteractionsLanguageModel(
			name: .init(id: "test", capabilities: .init()),
			auth: .apiKey("key")
		)
		let config = lm.executorConfiguration
		#expect(config.customHeaders.isEmpty)
	}

	@Test func proxiedAuthForwardsHeaders() {
		let headers = ["X-Token": "abc", "X-Org": "myorg"]
		let lm = GeminiInteractionsLanguageModel(
			name: .init(id: "test", capabilities: .init()),
			auth: .proxied(headers: headers)
		)
		let config = lm.executorConfiguration
		#expect(config.customHeaders == headers)
	}

	@Test func serviceTierPassedThrough() {
		let lm = GeminiInteractionsLanguageModel(
			name: .init(id: "test", capabilities: .init()),
			auth: .apiKey("key"),
			serviceTier: .flex
		)
		let config = lm.executorConfiguration
		#expect(config.serviceTier == .flex)
	}

	@Test func serviceTierNilByDefault() {
		let lm = GeminiInteractionsLanguageModel(
			name: .init(id: "test", capabilities: .init()),
			auth: .apiKey("key")
		)
		let config = lm.executorConfiguration
		#expect(config.serviceTier == nil)
	}

	@Test func modelEquality() {
		let a = GeminiInteractionsModel(id: "gemini-2.5-flash", capabilities: .init(reasoning: true))
		let b = GeminiInteractionsModel(id: "gemini-2.5-flash", capabilities: .init(reasoning: true))
		#expect(a == b)
		#expect(a.hashValue == b.hashValue)
	}
}
