// swift-tools-version: 6.2

import PackageDescription

let package = Package(
	name: "SwiftGeminiILanguageModel",
	platforms: [
		.iOS("27.0"), .macOS("27.0"), .visionOS("27.0"), .watchOS("27.0"),
	],
	products: [
		.library(
			name: "SwiftGeminiILanguageModel",
			targets: ["SwiftGeminiILanguageModel"]
		),
	],
	dependencies: [
		.package(url: "https://github.com/RichNasz/SwiftGeminiInteractions.git", branch: "main"),
	],
	targets: [
		.target(
			name: "SwiftGeminiILanguageModel",
			dependencies: [
				.product(name: "SwiftGeminiInteractions", package: "SwiftGeminiInteractions"),
			]
		),
		.testTarget(
			name: "SwiftGeminiILanguageModelTests",
			dependencies: ["SwiftGeminiILanguageModel"]
		),
	]
)
