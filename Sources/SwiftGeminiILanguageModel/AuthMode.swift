import Foundation

/// How authentication credentials are provided to the Gemini API.
///
/// - Important: `.apiKey` sends no custom headers; `.proxied` sends no `Authorization` header.
///   Choose the mode that matches your deployment.
public enum AuthMode: Sendable, Hashable {
	/// Direct Gemini API key authentication.
	///
	/// The key is passed to `InteractionsClient` and sent as the standard API key header.
	case apiKey(String)

	/// Enterprise or proxy authentication via custom HTTP headers.
	///
	/// The provided headers are forwarded on every request. No `Authorization` header is sent;
	/// the upstream proxy is responsible for authenticating with Gemini.
	case proxied(headers: [String: String])
}
