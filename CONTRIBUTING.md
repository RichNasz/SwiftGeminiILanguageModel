# Contributing to SwiftGeminiILanguageModel

Thanks for your interest in SwiftGeminiILanguageModel. Contributions via GitHub Issues are welcome.

## Reporting Bugs

Open a [GitHub Issue](https://github.com/RichNasz/SwiftGeminiILanguageModel/issues). Please include:

- What you expected to happen
- What actually happened
- Your Swift version and platform (macOS/iOS/visionOS)
- A minimal code snippet that reproduces the problem

## Requesting Features

Open a [GitHub Issue](https://github.com/RichNasz/SwiftGeminiILanguageModel/issues). Describe what you want and why — not how to implement it. The best feature requests focus on the problem to solve, not a specific solution.

## How Changes Are Made

This project uses spec-driven development. The [`Spec/`](Spec/) directory contains WHAT specs (desired behavior), HOW specs (implementation approach), and WHY specs (design rationale). Code is generated from these specs.

All changes start as a GitHub Issue. Issues are resolved interactively with an AI coding agent through this workflow:

1. Issue is raised (bug report or feature request)
2. AI agent analyzes the issue against existing specs
3. Specs are updated to reflect the change
4. Code is generated from the updated specs
5. Tests verify the implementation

**Code PRs are not accepted.** Unsolicited code PRs skip the spec step and can't be merged — the specs must be updated first so that design decisions are captured and code can be regenerated consistently. Feature ideas raised via issues may be implemented in a future release when they align with the project's direction.
