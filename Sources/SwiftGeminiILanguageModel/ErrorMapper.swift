import Foundation
import FoundationModels
import SwiftGeminiInteractions

/// Provider-specific errors from the Gemini API.
///
/// Some Gemini errors are mapped to `LanguageModelError` for framework compatibility
/// (rate limit, context size exceeded, timeout). These cases capture errors that
/// don't fit the standard framework error types. Catch both `GeminiILanguageModelError`
/// and `LanguageModelError` for full coverage.
public enum GeminiILanguageModelError: Error, Sendable {
	/// No API key or authentication was provided.
	case missingCredential
	/// HTTP error from the Gemini API with the status code and response body.
	case apiError(statusCode: Int, message: String)
	/// Error received during SSE streaming from the Gemini API.
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
