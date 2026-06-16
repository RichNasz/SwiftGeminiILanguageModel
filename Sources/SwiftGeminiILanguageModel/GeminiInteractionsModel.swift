import Foundation

public struct GeminiInteractionsModel: Sendable, Hashable {
	public let id: String
	public let capabilities: Capabilities

	public init(id: String, capabilities: Capabilities) {
		self.id = id
		self.capabilities = capabilities
	}

	public struct Capabilities: Sendable, Hashable {
		public var samplingParams: Bool
		public var reasoning: Bool
		public var structuredOutput: Bool
		public var imageInput: Bool
		public var toolCalling: Bool

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
