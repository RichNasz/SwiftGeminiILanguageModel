---
status: accepted
---

# SwiftGeminiILanguageModel Documentation Design

**Date:** 2026-06-16
**Status:** Accepted
**Audience:** Developers using FoundationModels who want to connect to Gemini; AI coding tools (AGENTS.md)

## Goal

Create a documentation suite for a project that has no README, CLAUDE.md, or AGENTS.md. The library is a thin adapter (4 public types, ~400 lines of implementation), and the documentation should be proportional. A single getting-started guide provides progressive depth from basic streaming through advanced features.

## Principles

1. **Proportionality** — 4 public types. One getting-started guide covers the full progression.
2. **Substitutability as the story** — The README shows the FoundationModels baseline (on-device) alongside the Gemini alternative. Only the model passed to `LanguageModelSession` changes.
3. **Progressive disclosure** — README shows install + one example. Getting-started guide builds from basic streaming through reasoning.
4. **Two audiences** — Humans read README and guide; AI tools read AGENTS.md; contributors read CLAUDE.md.
5. **No examples directory** — Code examples are self-contained in the getting-started guide.

---

## 1. README.md

**Purpose:** Landing page. Gets the reader from zero to first streaming response.

**Target length:** ~80-100 lines.

**Structure:**

### Badge Row
Five badges: Swift 6.2+, Platform, License (Apache 2.0), Version (0.1.0), Built with Claude Code.

### One-Sentence Description
Drop-in `LanguageModel` implementation connecting Apple's FoundationModels to Google's Gemini API via the Interactions protocol.

### Why Section
~15 lines on provider freedom: FoundationModels gives a unified API, this bridges to Gemini, thin adapter with three translation layers.

### The Swap
Two paired code blocks: on-device vs Gemini. Identical code except the session init.

### Installation
SPM snippet with `branch: "main"`.

### API Overview
Table of 4 public types.

### Capability Flags
Table of 5 flags with defaults.

### Next Steps / For AI Coding Tools / License

---

## 2. docs/getting-started.md

**Purpose:** Progressive guide from basic streaming through all features.

**Target length:** ~120-150 lines.

**Sections:** Basic Streaming, Auth Modes, Capability Flags, Tool Calling, Structured Output, Image Input, Reasoning.

---

## 3. CLAUDE.md

**Purpose:** AI contributor orientation.

**Target length:** ~60 lines.

**Sections:** Project overview, commands, architecture, file map, dependencies, spec files, testing strategy.

---

## 4. AGENTS.md

**Purpose:** Machine-readable patterns/pitfalls for AI tools consuming the library.

**Target length:** ~100-120 lines.

**Format:** Pattern/Pitfalls per topic.

---

## 5. CONTRIBUTING.md

**Purpose:** Spec-driven contribution model.

**Target length:** ~30 lines.

---

## File Changes Summary

**Create:**
- `README.md`
- `docs/getting-started.md`
- `CLAUDE.md`
- `AGENTS.md`
- `CONTRIBUTING.md`

**Untouched:**
- `Spec/` (spec files are separate from documentation)
- `Sources/` and `Tests/`
- `Package.swift`

---

## Verification

- [ ] README code examples use correct API signatures
- [ ] README swap shows identical usage with only session init differing
- [ ] Getting-started guide progresses from basic streaming through reasoning
- [ ] CLAUDE.md file map matches actual source files
- [ ] AGENTS.md patterns match current public API signatures
- [ ] CONTRIBUTING.md explains spec-driven workflow
- [ ] All cross-references between files resolve
