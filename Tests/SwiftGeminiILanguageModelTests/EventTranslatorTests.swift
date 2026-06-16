import Testing
import Foundation
import FoundationModels
import SwiftGeminiInteractions
@testable import SwiftGeminiILanguageModel

@Suite("EventTranslator")
struct EventTranslatorTests {

	// MARK: - Helpers

	private func makeStream(
		events: [InteractionStreamEvent]
	) -> AsyncThrowingStream<InteractionStreamEvent, Error> {
		AsyncThrowingStream { continuation in
			for event in events {
				continuation.yield(event)
			}
			continuation.finish()
		}
	}

	private func translate(
		events: [InteractionStreamEvent]
	) async throws {
		let translator = EventTranslator(
			responseEntryID: "resp-1",
			toolCallsEntryID: "tc-1"
		)
		let channel = LanguageModelExecutorGenerationChannel()
		try await translator.translate(makeStream(events: events), into: channel)
	}

	private func completedInteraction(
		usage: Usage? = nil
	) -> Interaction {
		Interaction(
			id: "int-1",
			object: "interaction",
			model: "gemini-2.5-flash",
			agent: nil,
			status: .completed,
			created: nil,
			updated: nil,
			steps: [],
			usage: usage,
			serviceTier: nil
		)
	}

	// MARK: - Content Deltas

	@Test func textDeltaProcessedSuccessfully() async throws {
		try await translate(events: [
			.stepStart(stepType: "model_output", index: 0),
			.stepDelta(.text("Hello"), stepIndex: 0),
			.stepDelta(.text(" world"), stepIndex: 0),
			.stepStop(index: 0),
			.interactionCompleted(completedInteraction())
		])
	}

	// MARK: - Function Calls

	@Test func functionCallArgumentsProcessed() async throws {
		try await translate(events: [
			.stepStart(stepType: "function_call", index: 0),
			.stepDelta(.functionCallArguments(delta: "{\"q\":", callId: "call-1"), stepIndex: 0),
			.stepDelta(.functionCallArguments(delta: "\"test\"}", callId: "call-1"), stepIndex: 0),
			.stepStop(index: 0),
			.interactionCompleted(completedInteraction())
		])
	}

	@Test func multipleFunctionCallsTrackedByIndex() async throws {
		try await translate(events: [
			.stepStart(stepType: "function_call", index: 0),
			.stepStart(stepType: "function_call", index: 1),
			.stepDelta(.functionCallArguments(delta: "{}", callId: "call-1"), stepIndex: 0),
			.stepDelta(.functionCallArguments(delta: "{}", callId: "call-2"), stepIndex: 1),
			.stepStop(index: 0),
			.stepStop(index: 1),
			.interactionCompleted(completedInteraction())
		])
	}

	// MARK: - Reasoning

	@Test func thoughtSummaryProcessed() async throws {
		try await translate(events: [
			.stepStart(stepType: "thought", index: 0),
			.stepDelta(.thoughtSummary("thinking..."), stepIndex: 0),
			.stepStop(index: 0),
			.interactionCompleted(completedInteraction())
		])
	}

	@Test func multipleThoughtSummariesReuseEntryID() async throws {
		try await translate(events: [
			.stepStart(stepType: "thought", index: 0),
			.stepDelta(.thoughtSummary("step 1"), stepIndex: 0),
			.stepDelta(.thoughtSummary(" step 2"), stepIndex: 0),
			.stepStop(index: 0),
			.interactionCompleted(completedInteraction())
		])
	}

	// MARK: - Completion & Usage

	@Test func interactionCompletedWithUsage() async throws {
		let usage = Usage(
			totalInputTokens: 100,
			totalOutputTokens: 50,
			totalThoughtTokens: 10,
			totalCachedTokens: 20,
			totalToolUseTokens: 0,
			totalTokens: 180
		)
		try await translate(events: [
			.stepDelta(.text("Hi"), stepIndex: 0),
			.interactionCompleted(completedInteraction(usage: usage))
		])
	}

	@Test func interactionCompletedWithNilUsage() async throws {
		try await translate(events: [
			.stepDelta(.text("Hi"), stepIndex: 0),
			.interactionCompleted(completedInteraction())
		])
	}

	@Test func noCompletionSendsFallbackUsage() async throws {
		try await translate(events: [
			.stepDelta(.text("Hello"), stepIndex: 0),
		])
	}

	// MARK: - Error Events

	@Test func errorEventThrowsStreamError() async {
		await #expect(throws: GeminiILanguageModelError.self) {
			try await translate(events: [
				.error("connection dropped")
			])
		}
	}

	// MARK: - Ignored Events

	@Test func ignoredEventsProcessWithoutError() async throws {
		try await translate(events: [
			.interactionCreated(completedInteraction()),
			.interactionStatusUpdate(.completed),
			.stepStart(stepType: "model_output", index: 0),
			.stepStop(index: 0),
			.interactionCompleted(completedInteraction())
		])
	}

	// MARK: - Mixed Event Sequences

	@Test func fullConversationSequence() async throws {
		let usage = Usage(
			totalInputTokens: 50,
			totalOutputTokens: 30,
			totalThoughtTokens: 0,
			totalCachedTokens: 0,
			totalToolUseTokens: 0,
			totalTokens: 80
		)
		try await translate(events: [
			.interactionCreated(completedInteraction()),
			.stepStart(stepType: "model_output", index: 0),
			.stepDelta(.text("Let me check"), stepIndex: 0),
			.stepStop(index: 0),
			.stepStart(stepType: "function_call", index: 1),
			.stepDelta(.functionCallArguments(delta: "{}", callId: "call-1"), stepIndex: 1),
			.stepStop(index: 1),
			.stepStart(stepType: "model_output", index: 2),
			.stepDelta(.text(" the date."), stepIndex: 2),
			.stepStop(index: 2),
			.interactionCompleted(completedInteraction(usage: usage))
		])
	}
}
