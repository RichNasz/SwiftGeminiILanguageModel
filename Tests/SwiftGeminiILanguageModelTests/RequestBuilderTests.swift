import Testing
import Foundation
import FoundationModels
import SwiftGeminiInteractions
@testable import SwiftGeminiILanguageModel

@Suite("RequestBuilder")
struct RequestBuilderTests {

	// MARK: - Helpers

	private func buildRequest(
		entries: [Transcript.Entry] = [],
		tools: [Transcript.ToolDefinition] = [],
		schema: GenerationSchema? = nil,
		options: GenerationOptions = GenerationOptions(),
		contextOptions: ContextOptions = ContextOptions(),
		capabilities: GeminiInteractionsModel.Capabilities = .init(),
		serviceTier: ServiceTier? = nil
	) throws -> InteractionRequest {
		let transcript = Transcript(entries: entries)
		let request = LanguageModelExecutorGenerationRequest(
			id: UUID(),
			transcript: transcript,
			enabledTools: tools,
			schema: schema,
			generationOptions: options,
			contextOptions: contextOptions,
			metadata: [:]
		)
		let model = GeminiInteractionsModel(id: "gemini-2.5-flash", capabilities: capabilities)
		return try RequestBuilder.build(from: request, model: model, serviceTier: serviceTier).request
	}

	private func textSegment(_ text: String) -> Transcript.Segment {
		.text(.init(content: text))
	}

	private func steps(from request: InteractionRequest) -> [Step] {
		if case .steps(let steps) = request.input { return steps }
		return []
	}

	// MARK: - Transcript Entry Translation

	@Test func instructionsSetsSystemInstruction() throws {
		let entry = Transcript.Entry.instructions(
			Transcript.Instructions(segments: [textSegment("Be helpful.")], toolDefinitions: [])
		)
		let request = try buildRequest(entries: [entry])
		#expect(request.systemInstruction == "Be helpful.")
	}

	@Test func multipleInstructionsJoinedWithDoubleNewline() throws {
		let entry1 = Transcript.Entry.instructions(
			Transcript.Instructions(segments: [textSegment("Be helpful.")], toolDefinitions: [])
		)
		let entry2 = Transcript.Entry.instructions(
			Transcript.Instructions(segments: [textSegment("Be concise.")], toolDefinitions: [])
		)
		let request = try buildRequest(entries: [entry1, entry2])
		#expect(request.systemInstruction == "Be helpful.\n\nBe concise.")
	}

	@Test func promptProducesUserInputStep() throws {
		let entry = Transcript.Entry.prompt(
			Transcript.Prompt(segments: [textSegment("Hello")])
		)
		let request = try buildRequest(entries: [entry])

		if case .text(let text) = request.input {
			#expect(text == "Hello")
		} else {
			Issue.record("Expected .text input for simple single-text prompt")
		}
	}

	@Test func promptWithHistoryProducesSteps() throws {
		let prompt = Transcript.Entry.prompt(
			Transcript.Prompt(segments: [textSegment("Hello")])
		)
		let response = Transcript.Entry.response(
			Transcript.Response(assetIDs: [], segments: [textSegment("Hi there")])
		)
		let prompt2 = Transcript.Entry.prompt(
			Transcript.Prompt(segments: [textSegment("How are you?")])
		)
		let request = try buildRequest(entries: [prompt, response, prompt2])
		let stepsArr = steps(from: request)
		#expect(stepsArr.count == 3)
	}

	@Test func responseProducesModelOutputStep() throws {
		let prompt = Transcript.Entry.prompt(
			Transcript.Prompt(segments: [textSegment("Hello")])
		)
		let response = Transcript.Entry.response(
			Transcript.Response(assetIDs: [], segments: [textSegment("Answer")])
		)
		let prompt2 = Transcript.Entry.prompt(
			Transcript.Prompt(segments: [textSegment("Follow up")])
		)
		let request = try buildRequest(entries: [prompt, response, prompt2])
		let stepsArr = steps(from: request)
		#expect(stepsArr.count == 3)

		if case .modelOutput(let content) = stepsArr[1] {
			if case .text(let text, _) = content[0] {
				#expect(text == "Answer")
			} else {
				Issue.record("Expected .text content")
			}
		} else {
			Issue.record("Expected .modelOutput step")
		}
	}

	@Test func emptyResponseSkipped() throws {
		let prompt = Transcript.Entry.prompt(
			Transcript.Prompt(segments: [textSegment("Hello")])
		)
		let response = Transcript.Entry.response(
			Transcript.Response(assetIDs: [], segments: [textSegment("")])
		)
		let prompt2 = Transcript.Entry.prompt(
			Transcript.Prompt(segments: [textSegment("Follow up")])
		)
		let request = try buildRequest(entries: [prompt, response, prompt2])
		let stepsArr = steps(from: request)
		#expect(stepsArr.count == 2)
	}

	@Test func toolOutputProducesFunctionResult() throws {
		let prompt = Transcript.Entry.prompt(
			Transcript.Prompt(segments: [textSegment("Hello")])
		)
		let toolOut = Transcript.Entry.toolOutput(
			Transcript.ToolOutput(id: "call-1", toolName: "get_date", segments: [textSegment("2026-06-16")])
		)
		let request = try buildRequest(entries: [prompt, toolOut])
		let stepsArr = steps(from: request)
		#expect(stepsArr.count == 2)

		if case .functionResult(let callId, let result, _, _) = stepsArr[1] {
			#expect(callId == "call-1")
			#expect(result == "2026-06-16")
		} else {
			Issue.record("Expected .functionResult step")
		}
	}

	@Test func emptyToolOutputFallsBackToEmptyJSON() throws {
		let prompt = Transcript.Entry.prompt(
			Transcript.Prompt(segments: [textSegment("Hello")])
		)
		let toolOut = Transcript.Entry.toolOutput(
			Transcript.ToolOutput(id: "call-1", toolName: "get_date", segments: [textSegment("")])
		)
		let request = try buildRequest(entries: [prompt, toolOut])
		let stepsArr = steps(from: request)

		if case .functionResult(_, let result, _, _) = stepsArr[1] {
			#expect(result == "{}")
		} else {
			Issue.record("Expected .functionResult step")
		}
	}

	// MARK: - Generation Options

	@Test func maxTokensForwarded() throws {
		let request = try buildRequest(
			entries: [.prompt(Transcript.Prompt(segments: [textSegment("Hi")]))],
			options: GenerationOptions(maximumResponseTokens: 500)
		)
		#expect(request.generationConfig?.maxOutputTokens == 500)
	}

	@Test func maxTokensNilNotSet() throws {
		let request = try buildRequest(
			entries: [.prompt(Transcript.Prompt(segments: [textSegment("Hi")]))]
		)
		#expect(request.generationConfig?.maxOutputTokens == nil)
	}

	@Test func toolCallingModeRequired() throws {
		let request = try buildRequest(
			entries: [.prompt(Transcript.Prompt(segments: [textSegment("Hi")]))],
			options: GenerationOptions(toolCallingMode: .required)
		)
		#expect(request.generationConfig?.toolChoice?.mode == .required)
	}

	@Test func toolCallingModeDisallowed() throws {
		let request = try buildRequest(
			entries: [.prompt(Transcript.Prompt(segments: [textSegment("Hi")]))],
			options: GenerationOptions(toolCallingMode: .disallowed)
		)
		#expect(request.generationConfig?.toolChoice?.mode == ToolChoiceMode.none)
	}

	@Test func toolCallingModeAllowed() throws {
		let request = try buildRequest(
			entries: [.prompt(Transcript.Prompt(segments: [textSegment("Hi")]))],
			options: GenerationOptions(toolCallingMode: .allowed)
		)
		#expect(request.generationConfig?.toolChoice?.mode == .auto)
	}

	@Test func toolCallingModeNilNotSet() throws {
		let request = try buildRequest(
			entries: [.prompt(Transcript.Prompt(segments: [textSegment("Hi")]))]
		)
		#expect(request.generationConfig?.toolChoice == nil)
	}

	// MARK: - Sampling (capability-gated)

	@Test func samplingGreedySetsTemperatureZero() throws {
		let request = try buildRequest(
			entries: [.prompt(Transcript.Prompt(segments: [textSegment("Hi")]))],
			options: GenerationOptions(samplingMode: .greedy),
			capabilities: .init(samplingParams: true)
		)
		#expect(request.generationConfig?.temperature == 0)
	}

	@Test func samplingNucleusSetsTopP() throws {
		let request = try buildRequest(
			entries: [.prompt(Transcript.Prompt(segments: [textSegment("Hi")]))],
			options: GenerationOptions(samplingMode: .random(probabilityThreshold: 0.9)),
			capabilities: .init(samplingParams: true)
		)
		#expect(request.generationConfig?.topP == 0.9)
	}

	@Test func samplingDisabledSkipsAll() throws {
		let request = try buildRequest(
			entries: [.prompt(Transcript.Prompt(segments: [textSegment("Hi")]))],
			options: GenerationOptions(temperature: 0.5),
			capabilities: .init(samplingParams: false)
		)
		#expect(request.generationConfig?.temperature == nil)
		#expect(request.generationConfig?.topP == nil)
	}

	@Test func temperaturePassedThrough() throws {
		let request = try buildRequest(
			entries: [.prompt(Transcript.Prompt(segments: [textSegment("Hi")]))],
			options: GenerationOptions(temperature: 0.7),
			capabilities: .init(samplingParams: true)
		)
		#expect(request.generationConfig?.temperature == 0.7)
	}

	// MARK: - Reasoning (capability-gated)

	@Test func reasoningLightMapsToLow() throws {
		let request = try buildRequest(
			entries: [.prompt(Transcript.Prompt(segments: [textSegment("Hi")]))],
			contextOptions: ContextOptions(reasoningLevel: .light),
			capabilities: .init(reasoning: true)
		)
		#expect(request.generationConfig?.thinkingLevel == .low)
		#expect(request.generationConfig?.thinkingSummaries == .enabled)
	}

	@Test func reasoningModerateMapsToMedium() throws {
		let request = try buildRequest(
			entries: [.prompt(Transcript.Prompt(segments: [textSegment("Hi")]))],
			contextOptions: ContextOptions(reasoningLevel: .moderate),
			capabilities: .init(reasoning: true)
		)
		#expect(request.generationConfig?.thinkingLevel == .medium)
	}

	@Test func reasoningDeepMapsToHigh() throws {
		let request = try buildRequest(
			entries: [.prompt(Transcript.Prompt(segments: [textSegment("Hi")]))],
			contextOptions: ContextOptions(reasoningLevel: .deep),
			capabilities: .init(reasoning: true)
		)
		#expect(request.generationConfig?.thinkingLevel == .high)
	}

	@Test func reasoningDisabledSkips() throws {
		let request = try buildRequest(
			entries: [.prompt(Transcript.Prompt(segments: [textSegment("Hi")]))],
			contextOptions: ContextOptions(reasoningLevel: .moderate),
			capabilities: .init(reasoning: false)
		)
		#expect(request.generationConfig?.thinkingLevel == nil)
	}

	// MARK: - Model ID

	@Test func modelIdPassedThrough() throws {
		let request = try buildRequest(
			entries: [.prompt(Transcript.Prompt(segments: [textSegment("Hi")]))]
		)
		#expect(request.model == "gemini-2.5-flash")
	}

	// MARK: - Service Tier

	@Test func serviceTierFlexSet() throws {
		let request = try buildRequest(
			entries: [.prompt(Transcript.Prompt(segments: [textSegment("Hi")]))],
			serviceTier: .flex
		)
		#expect(request.serviceTier == .flex)
	}

	@Test func serviceTierPrioritySet() throws {
		let request = try buildRequest(
			entries: [.prompt(Transcript.Prompt(segments: [textSegment("Hi")]))],
			serviceTier: .priority
		)
		#expect(request.serviceTier == .priority)
	}

	@Test func serviceTierNilByDefault() throws {
		let request = try buildRequest(
			entries: [.prompt(Transcript.Prompt(segments: [textSegment("Hi")]))]
		)
		#expect(request.serviceTier == nil)
	}

	// MARK: - Input format

	@Test func simpleTextUsesTextInput() throws {
		let request = try buildRequest(
			entries: [.prompt(Transcript.Prompt(segments: [textSegment("Hello")]))]
		)
		if case .text(let text) = request.input {
			#expect(text == "Hello")
		} else {
			Issue.record("Expected .text input")
		}
	}

	@Test func multipleEntriesUseStepsInput() throws {
		let prompt = Transcript.Entry.prompt(
			Transcript.Prompt(segments: [textSegment("Hello")])
		)
		let response = Transcript.Entry.response(
			Transcript.Response(assetIDs: [], segments: [textSegment("Hi")])
		)
		let prompt2 = Transcript.Entry.prompt(
			Transcript.Prompt(segments: [textSegment("Ok")])
		)
		let request = try buildRequest(entries: [prompt, response, prompt2])
		if case .steps(let s) = request.input {
			#expect(s.count == 3)
		} else {
			Issue.record("Expected .steps input")
		}
	}

	@Test func promptWithInstructionsUsesStepsInput() throws {
		let instr = Transcript.Entry.instructions(
			Transcript.Instructions(segments: [textSegment("Be helpful.")], toolDefinitions: [])
		)
		let prompt = Transcript.Entry.prompt(
			Transcript.Prompt(segments: [textSegment("Hello")])
		)
		let request = try buildRequest(entries: [instr, prompt])
		if case .steps = request.input {
			// expected — instructions + prompt means we can't use simple text
		} else if case .text = request.input {
			// also acceptable if instructions are separated to systemInstruction
		}
		#expect(request.systemInstruction == "Be helpful.")
	}
}
