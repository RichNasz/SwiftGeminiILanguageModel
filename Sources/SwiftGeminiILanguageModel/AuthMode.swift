import Foundation

public enum AuthMode: Sendable, Hashable {
	case apiKey(String)
	case proxied(headers: [String: String])
}
