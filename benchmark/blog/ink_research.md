# Ink TUI Framework - Deep Technical Research

## Executive Summary

Ink is a React renderer for terminal UIs with 34.5k GitHub stars and ~1M weekly npm downloads. It uses React's reconciler with Yoga layout engine (C++) for Flexbox in the terminal. Version 3 claimed 2x performance improvement for high-frequency re-renders.

## Architecture

### React Reconciler Integration
- Built on `react-reconciler`, Facebook's package for creating custom React renderers
- Provides custom host primitives (`<Text>`, `<Box>`, etc.) instead of DOM elements
- Full React feature set: hooks, context, suspense

### Yoga Layout Engine
- Meta's cross-platform Flexbox layout engine written in C++
- Distributed as WebAssembly (~45KB gzipped) for JavaScript
- 33% improvement over previous Java implementation

### Notable Users
- Claude Code (Anthropic) - rewrote renderer for fine-grained incremental updates
- Gemini CLI (Google)
- GitHub Copilot CLI
- OpenAI Codex CLI (migrating to Rust for performance)
- Cloudflare Wrangler, Prisma, Gatsby, Shopify CLI

## Key Performance Characteristics

### Strengths
- 2x faster re-renders in v3
- `<Static>` component for virtualization
- Incremental rendering mode
- Mature ecosystem

### Weaknesses
- FFI overhead to Yoga (C++)
- JavaScript runtime overhead
- Flickering with large outputs (Issue #359)
- Terminal-specific quirks

## Comparison Points for Nocterm

| Aspect | Ink | Nocterm |
|--------|-----|---------|
| Rendering Model | React reconciler | Flutter widget tree |
| Layout Engine | Yoga (C++ FFI) | Native Dart |
| Language | TypeScript | Dart |
| Binary | Requires Node.js | AOT compiled |

## Sources
- GitHub: https://github.com/vadimdemedes/ink
- Ink v3 announcement: https://vadimdemedes.com/posts/ink-3
- Yoga: https://yogalayout.dev/
- Claude Code architecture: https://newsletter.pragmaticengineer.com/p/how-claude-code-is-built
