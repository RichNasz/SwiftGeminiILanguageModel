import Foundation
import FoundationModels
import SwiftGeminiInteractions

@available(macOS 27.0, iOS 27.0, visionOS 27.0, watchOS 27.0, *)
struct EventTranslator: Sendable {
	let responseEntryID: String
	let toolCallsEntryID: String

	init(
		responseEntryID: String = UUID().uuidString,
		toolCallsEntryID: String = UUID().uuidString
	) {
		self.responseEntryID = responseEntryID
		self.toolCallsEntryID = toolCallsEntryID
	}

	func translate(
		_ events: AsyncThrowingStream<InteractionStreamEvent, Error>,
		into channel: LanguageModelExecutorGenerationChannel
	) async throws {
		var activeFunctionCalls: [Int: String] = [:]
		var reasoningEntryID: String?
		var sentCompletion = false

		for try await event in events {
			try Task.checkCancellation()

			switch event {
			case .stepDelta(let delta, let stepIndex):
				switch delta {
				case .text(let text):
					await channel.send(
						.response(
							entryID: responseEntryID,
							action: .appendText(text, tokenCount: 0)
						)
					)

				case .functionCallArguments(let argDelta, let callId):
					if activeFunctionCalls[stepIndex] == nil {
						activeFunctionCalls[stepIndex] = callId
						await channel.send(
							.toolCalls(
								entryID: toolCallsEntryID,
								action: .toolCall(
									id: callId,
									name: "",
									action: .appendArguments("", tokenCount: 0)
								)
							)
						)
					}

					await channel.send(
						.toolCalls(
							entryID: toolCallsEntryID,
							action: .toolCall(
								id: callId,
								name: "",
								action: .appendArguments(argDelta, tokenCount: 0)
							)
						)
					)

				case .thoughtSummary(let text):
					let entryID: String
					if let existing = reasoningEntryID {
						entryID = existing
					} else {
						let id = UUID().uuidString
						reasoningEntryID = id
						entryID = id
					}
					await channel.send(
						.reasoning(
							entryID: entryID,
							action: .appendText(text, tokenCount: 0)
						)
					)

				case .image, .codeExecutionArguments, .googleSearchQuery,
					 .urlContextUrl, .annotation, .unknown:
					break
				}

			case .stepStart(let stepType, let index):
				if stepType == "function_call" {
					activeFunctionCalls[index] = nil
				}

			case .interactionCompleted(let interaction):
				let inputTokens = interaction.usage?.totalInputTokens ?? 0
				let outputTokens = interaction.usage?.totalOutputTokens ?? 0
				let cachedTokens = interaction.usage?.totalCachedTokens ?? 0
				let reasoningTokens = interaction.usage?.totalThoughtTokens ?? 0

				await channel.send(
					.response(
						entryID: responseEntryID,
						action: .updateUsage(
							input: .init(
								totalTokenCount: inputTokens,
								cachedTokenCount: cachedTokens
							),
							output: .init(
								totalTokenCount: outputTokens,
								reasoningTokenCount: reasoningTokens
							)
						)
					)
				)
				sentCompletion = true

			case .error(let message):
				throw GeminiILanguageModelError.streamError(message)

			case .interactionCreated, .interactionStatusUpdate, .stepStop, .unknown:
				break
			}
		}

		if !sentCompletion {
			await channel.send(
				.response(
					entryID: responseEntryID,
					action: .updateUsage(
						input: .init(totalTokenCount: 0, cachedTokenCount: 0),
						output: .init(totalTokenCount: 0, reasoningTokenCount: 0)
					)
				)
			)
		}
	}
}
