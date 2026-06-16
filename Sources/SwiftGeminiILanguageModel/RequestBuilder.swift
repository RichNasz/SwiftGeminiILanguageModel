import Foundation
import FoundationModels
import SwiftGeminiInteractions
import CoreGraphics
import ImageIO

@available(macOS 27.0, iOS 27.0, visionOS 27.0, watchOS 27.0, *)
enum RequestBuilder {

	struct Built {
		var request: InteractionRequest
	}

	static func build(
		from request: LanguageModelExecutorGenerationRequest,
		model: GeminiInteractionsModel,
		serviceTier: ServiceTier? = nil
	) throws -> Built {
		var instructions: String?
		var steps: [Step] = []

		for entry in request.transcript {
			switch entry {
			case .instructions(let i):
				let text = segmentsToText(i.segments)
				if let existing = instructions {
					instructions = existing + "\n\n" + text
				} else {
					instructions = text
				}

			case .prompt(let p):
				let content = segmentsToContent(p.segments)
				if !content.isEmpty {
					steps.append(.userInput(content: content))
				}

			case .response(let r):
				let text = segmentsToText(r.segments)
				if !text.isEmpty {
					steps.append(.modelOutput(content: [.text(text, annotations: nil)]))
				}

			case .toolCalls(let calls):
				for call in calls {
					steps.append(
						.functionCall(
							id: call.id,
							name: call.toolName,
							arguments: call.arguments.jsonString
						)
					)
				}

			case .toolOutput(let out):
				let text = segmentsToText(out.segments)
				steps.append(
					.functionResult(
						callId: out.id,
						result: text.isEmpty ? "{}" : text,
						name: nil,
						isError: nil
					)
				)

			case .reasoning:
				break

			@unknown default:
				break
			}
		}

		let tools: [InteractionTool] = request.enabledToolDefinitions.map { def in
			.function(
				name: def.name,
				description: def.description,
				parameters: jsonSchemaValueFromGenerationSchema(def.parameters)
			)
		}

		let input: InteractionInput
		if steps.count == 1,
		   case .userInput(let content) = steps[0],
		   content.count == 1,
		   case .text(let text, _) = content[0],
		   instructions == nil,
		   tools.isEmpty {
			input = .text(text)
		} else {
			input = .steps(steps)
		}

		var interactionRequest = InteractionRequest(input: input)
		interactionRequest.model = model.id

		if let instructions {
			interactionRequest.systemInstruction = instructions
		}

		if !tools.isEmpty {
			interactionRequest.tools = tools
		}

		var genConfig = GenerationConfig()
		var hasGenConfig = false

		if let maxTokens = request.generationOptions.maximumResponseTokens {
			genConfig.maxOutputTokens = maxTokens
			hasGenConfig = true
		}

		applyToolChoice(request.generationOptions.toolCallingMode, to: &genConfig, hasConfig: &hasGenConfig)
		applySampling(request.generationOptions, to: &genConfig, model: model, hasConfig: &hasGenConfig)
		applyReasoning(request.contextOptions, to: &genConfig, model: model, hasConfig: &hasGenConfig)

		if hasGenConfig {
			interactionRequest.generationConfig = genConfig
		}

		applyStructuredOutput(request.schema, to: &interactionRequest, model: model)

		if let serviceTier {
			interactionRequest.serviceTier = serviceTier
		}

		return Built(request: interactionRequest)
	}

	// MARK: - Private

	private static func segmentsToText(_ segments: [Transcript.Segment]) -> String {
		segments.compactMap {
			switch $0 {
			case .text(let t): t.content
			case .structure(let s): s.content.jsonString
			case .attachment, .custom: nil
			@unknown default: nil
			}
		}
		.joined(separator: "\n")
	}

	private static func segmentsToContent(_ segments: [Transcript.Segment]) -> [Content] {
		segments.compactMap { segment -> Content? in
			switch segment {
			case .text(let t) where !t.content.isEmpty:
				return .text(t.content, annotations: nil)
			case .text:
				return nil
			case .structure(let s):
				return .text(s.content.jsonString, annotations: nil)
			case .attachment(let a):
				switch a.content {
				case .image(let img):
					if let url = img.url, !url.isFileURL {
						return .image(data: nil, mimeType: nil, uri: url.absoluteString)
					}
					guard let jpegData = cgImageToData(img.cgImage) else { return nil }
					return .image(data: jpegData, mimeType: "image/jpeg", uri: nil)
				@unknown default:
					return nil
				}
			case .custom:
				return nil
			@unknown default:
				return nil
			}
		}
	}

	private static func applyToolChoice(
		_ mode: GenerationOptions.ToolCallingMode?,
		to config: inout GenerationConfig,
		hasConfig: inout Bool
	) {
		guard let mode else { return }
		let toolChoiceMode: ToolChoiceMode = switch mode.kind {
		case .required: .required
		case .disallowed: .none
		case .allowed: .auto
		@unknown default: .auto
		}
		config.toolChoice = ToolChoiceConfig(mode: toolChoiceMode)
		hasConfig = true
	}

	private static func applySampling(
		_ options: GenerationOptions,
		to config: inout GenerationConfig,
		model: GeminiInteractionsModel,
		hasConfig: inout Bool
	) {
		guard model.capabilities.samplingParams else { return }

		if let temp = options.temperature {
			config.temperature = temp
			hasConfig = true
		}

		switch options.samplingMode?.kind {
		case .greedy:
			config.temperature = 0
			hasConfig = true
		case .nucleus(let threshold, _):
			config.topP = threshold
			hasConfig = true
		case .top, nil:
			break
		@unknown default:
			break
		}
	}

	private static func applyReasoning(
		_ options: ContextOptions,
		to config: inout GenerationConfig,
		model: GeminiInteractionsModel,
		hasConfig: inout Bool
	) {
		guard model.capabilities.reasoning else { return }

		let level: ThinkingLevel? = switch options.reasoningLevel {
		case .light: .low
		case .moderate: .medium
		case .deep: .high
		case .custom(let level): ThinkingLevel(rawValue: level)
		default: nil
		}

		if let level {
			config.thinkingLevel = level
			config.thinkingSummaries = .enabled
			hasConfig = true
		}
	}

	private static func applyStructuredOutput(
		_ schema: GenerationSchema?,
		to request: inout InteractionRequest,
		model: GeminiInteractionsModel
	) {
		guard let schema, model.capabilities.structuredOutput else { return }
		let jsonSchema = jsonSchemaValueFromGenerationSchema(schema)
		request.responseFormat = .text(mimeType: "application/json", schema: jsonSchema)
	}

	static func jsonSchemaValueFromGenerationSchema(_ schema: GenerationSchema) -> JSONSchemaValue {
		guard let data = try? JSONEncoder().encode(schema),
			  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
			return .object(properties: [], required: [])
		}
		return convertToJSONSchemaValue(dict)
	}

	private static func convertToJSONSchemaValue(_ value: Any) -> JSONSchemaValue {
		guard let dict = value as? [String: Any],
			  let type = dict["type"] as? String else {
			if let dict = value as? [String: Any] {
				return convertObjectToJSONSchemaValue(dict)
			}
			return .string()
		}

		switch type {
		case "object":
			return convertObjectToJSONSchemaValue(dict)
		case "array":
			if let items = dict["items"] {
				return .array(items: convertToJSONSchemaValue(items))
			}
			return .array(items: .string())
		case "string":
			let desc = dict["description"] as? String
			let enumVals = dict["enum"] as? [String]
			return .string(description: desc, enumValues: enumVals)
		case "integer":
			let desc = dict["description"] as? String
			let min = dict["minimum"] as? Int
			let max = dict["maximum"] as? Int
			return .integer(description: desc, minimum: min, maximum: max)
		case "number":
			let desc = dict["description"] as? String
			let min = dict["minimum"] as? Double
			let max = dict["maximum"] as? Double
			return .number(description: desc, minimum: min, maximum: max)
		case "boolean":
			let desc = dict["description"] as? String
			return .boolean(description: desc)
		default:
			return .string()
		}
	}

	private static func cgImageToData(_ cgImage: CGImage) -> Data? {
		let data = NSMutableData()
		guard let destination = CGImageDestinationCreateWithData(
			data, "public.jpeg" as CFString, 1, nil
		) else { return nil }
		CGImageDestinationAddImage(
			destination, cgImage,
			[kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary
		)
		guard CGImageDestinationFinalize(destination) else { return nil }
		return data as Data
	}

	private static func convertObjectToJSONSchemaValue(_ dict: [String: Any]) -> JSONSchemaValue {
		let properties = dict["properties"] as? [String: Any] ?? [:]
		let required = dict["required"] as? [String] ?? []
		let props: [(String, JSONSchemaValue)] = properties
			.sorted { $0.key < $1.key }
			.map { ($0.key, convertToJSONSchemaValue($0.value)) }
		return .object(properties: props, required: required)
	}
}
