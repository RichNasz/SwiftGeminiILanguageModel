import Testing
import Foundation
import FoundationModels
import SwiftGeminiInteractions
@testable import SwiftGeminiILanguageModel

@Suite("ErrorMapper")
struct ErrorMapperTests {

	@Test func rateLimitMapsToRateLimited() {
		let mapped = ErrorMapper.map(GeminiInteractionsError.rateLimitExceeded)
		#expect(mapped is LanguageModelError)
	}

	@Test func httpError413MapsToContextSizeExceeded() {
		let mapped = ErrorMapper.map(GeminiInteractionsError.httpError(statusCode: 413, body: "too big"))
		#expect(mapped is LanguageModelError)
	}

	@Test func httpError413EmptyBodyUsesDefault() {
		let mapped = ErrorMapper.map(GeminiInteractionsError.httpError(statusCode: 413, body: ""))
		#expect(mapped is LanguageModelError)
	}

	@Test func networkErrorMapsToTimeout() {
		let mapped = ErrorMapper.map(GeminiInteractionsError.networkError(URLError(.timedOut)))
		#expect(mapped is LanguageModelError)
	}

	@Test func otherHttpErrorMapsToApiError() {
		let mapped = ErrorMapper.map(GeminiInteractionsError.httpError(statusCode: 500, body: "internal error"))
		#expect(mapped is GeminiILanguageModelError)
	}

	@Test func nonGeminiErrorPassesThrough() {
		struct CustomError: Error {}
		let error = CustomError()
		let mapped = ErrorMapper.map(error)
		#expect(mapped is CustomError)
	}

	@Test func decodingErrorPassesThrough() {
		let context = DecodingError.Context(codingPath: [], debugDescription: "test")
		let error = GeminiInteractionsError.decodingError(DecodingError.dataCorrupted(context))
		let mapped = ErrorMapper.map(error)
		#expect(mapped is GeminiInteractionsError)
	}
}
