import Foundation
import FoundationModels
import SwiftGeminiInteractions

public enum GeminiILanguageModelError: Error, Sendable {
	case missingCredential
	case apiError(statusCode: Int, message: String)
	case streamError(String)
}

@available(macOS 27.0, iOS 27.0, visionOS 27.0, watchOS 27.0, *)
enum ErrorMapper {
	static func map(_ error: Error) -> Error {
		if let geminiError = error as? GeminiInteractionsError {
			return mapGeminiError(geminiError)
		}
		return error
	}

	private static func mapGeminiError(_ error: GeminiInteractionsError) -> Error {
		switch error {
		case .rateLimitExceeded:
			return LanguageModelError.rateLimited(
				.init(resetDate: nil, debugDescription: "Rate limit exceeded")
			)
		case .httpError(let statusCode, let body) where statusCode == 413:
			return LanguageModelError.contextSizeExceeded(
				.init(
					contextSize: 0,
					tokenCount: 0,
					debugDescription: body.isEmpty ? "Request exceeded context size limit" : body
				)
			)
		case .networkError:
			return LanguageModelError.timeout(.init(debugDescription: "Network error"))
		case .httpError(let statusCode, let body):
			return GeminiILanguageModelError.apiError(
				statusCode: statusCode,
				message: body.isEmpty ? "HTTP error \(statusCode)" : body
			)
		default:
			return error
		}
	}
}
