# Why I Built a TUI Framework in Dart (And Benchmarked It Against Ink)

Something interesting is happening in terminals. Claude Code, GitHub Copilot, Gemini CLI, Warp, Ghostty - suddenly everyone's building rich terminal interfaces. After years of simple `print()` statements, we're seeing React-style components, animations, and complex layouts right in our terminals.

I've been obsessed with this space. When I started building [Nocterm](https://github.com/your-repo/nocterm), I had a hypothesis: Flutter's rendering architecture - the same engine powering millions of mobile apps - would be perfect for terminals. Not "adapted" for terminals. *Built* for them.

This post is about that hypothesis. I built equivalent test applications in both Ink (the React-based TUI framework) and Nocterm, then measured everything I could. Here's what I found.

---

## Why Dart? Why Flutter's Architecture?

Before the benchmarks, let me explain why I went down this path.

### The Dart Ecosystem is Underrated

Dart has some properties that make it exceptionally well-suited for TUI development:

**AOT Compilation**: Dart compiles to native binaries. No runtime required. Copy a file, run it. That's the entire deployment story.

**Sound Null Safety**: After years of TypeScript's structural typing, Dart's sound type system is refreshing. When the compiler says something isn't null, it actually isn't null.

**Isolates**: Dart's concurrency model is perfect for TUIs. You can run expensive computations without blocking the UI thread - the same pattern that makes Flutter feel smooth.

**The Flutter Ecosystem**: 160k+ GitHub stars. Battle-tested rendering pipeline. Thousands of packages. When you build on Flutter's patterns, you're building on a decade of optimization work.

### Flutter's Three-Tree Architecture

Flutter doesn't just have components. It has three synchronized trees:

```
Component Tree    →    Element Tree    →    RenderObject Tree
(what you write)      (lifecycle mgmt)     (layout & paint)
```

This separation is why Flutter is fast. The Element tree can diff efficiently. The RenderObject tree can skip layout for unchanged subtrees. Dirty tracking happens at the right granularity.

Nocterm implements this same architecture for terminals. When you write a `StatefulComponent`, you get the same lifecycle, the same `setState()`, the same rebuild semantics.

---

## The Test Setup

I built 5 equivalent applications in each framework:

| Test | What It Measures |
|------|------------------|
| **Static Layout** | Baseline render - how fast can you draw a screen? |
| **Counter** | Minimal state change - what's the cost of updating one number? |
| **Scrolling List** | 1000 items, virtualized - can you handle real data? |
| **Rapid Input** | Keystroke-to-render - how responsive does it feel? |
| **Dashboard** | Multiple animations, live updates - sustained performance |

Both implementations use idiomatic patterns for their framework. Same visual output. Same functionality.

**Environment**: Apple M4 Pro, 48GB RAM, macOS (arm64), Terminal size 80x24

---

## The Numbers

### Startup Time

> **How I measured this**: Each app emits a `first_frame` timestamp to stderr when its first frame completes rendering. I ran each app in a headless PTY (using node-pty + xterm.js) and extracted this timing. The measurement starts when app code begins executing, not including process spawn overhead. I ran 10 samples per test.

```
First Frame Render Time (10 samples each)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Ink     ████████████████████████████████████████ 12.0ms
Nocterm █ 0.37ms
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                               32x faster
```

**Static Layout (baseline render):**

| Framework | Mean | Median | Min | Max | Std Dev | p95 |
|-----------|------|--------|-----|-----|---------|-----|
| Ink | 12.01ms | 12.02ms | 11.84ms | 12.15ms | 0.10ms | 12.13ms |
| Nocterm | 0.37ms | 0.36ms | 0.31ms | 0.44ms | 0.05ms | 0.43ms |

**Across all test apps:**

| App | Nocterm | Ink | Speedup |
|-----|---------|-----|---------|
| Static Layout | 0.37ms | 12.0ms | 32x |
| Counter | 0.47ms | 10.4ms | 22x |
| Dashboard | 0.47ms | 14.0ms | 30x |

Where does the 10-14ms go in Ink?
- Node.js runtime initialization
- Module resolution and loading
- React reconciler setup
- Yoga layout engine initialization (C++ via WASM)
- V8 JIT warmup

Nocterm is AOT-compiled. The binary loads, runs, and renders. There's no runtime to start.

---

### Binary Size

> **How I measured this**: For Nocterm, I compiled with `dart compile exe` and measured the resulting binary. For Ink, I measured the `node_modules` folder size after `npm install` - this is what you need to deploy. I also tested stripping the Nocterm binary to see the minimum size.

```
Deployment Size
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Ink     ████████████████████████████████████████ 43.1 MB
Nocterm ███████ 7.4 MB
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                               5.8x smaller
```

| Framework | Size | What's Included |
|-----------|------|-----------------|
| Ink | 43.1 MB | node_modules (React, Ink, Yoga, chalk, dozens of deps) |
| Nocterm | 7.4 MB | Single AOT binary (everything included) |
| Nocterm (stripped) | 7.4 MB | Minimal size reduction - already optimized |

The Ink number doesn't include Node.js itself. If you need a standalone executable (using pkg or nexe), add another 40+ MB for the Node runtime.

What you ship:
- **Ink**: `node_modules/` folder (43 MB, hundreds of files) + requires Node.js on target
- **Nocterm**: One file (7.4 MB) + nothing else

---

### Memory Usage

> **How I measured this**: I used `/usr/bin/time -l` on macOS to measure peak RSS (maximum resident set size) after each app renders and processes some input. This captures the full memory footprint including the runtime, not just heap allocations.

```
Peak Memory (RSS)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Ink     ████████████████████████████████████████ 102.4 MB
Nocterm ███████ 18.9 MB
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                               5.4x less memory
```

| App | Nocterm | Ink | Reduction |
|-----|---------|-----|-----------|
| Static Layout | 18.4 MB | 97.7 MB | 5.3x |
| Counter | 18.2 MB | 102.9 MB | 5.7x |
| Dashboard | 20.1 MB | 106.6 MB | 5.3x |
| **Average** | **18.9 MB** | **102.4 MB** | **5.4x** |

The ~100 MB for Ink is the baseline for *any* Ink application. That's Node.js + V8 heap + React + Yoga before your code runs.

Nocterm's ~19 MB is the full Dart runtime + your app. For a TUI framework, that's quite lean.

---

### Interactive Frame Times

> **How I measured this**: I ran each interactive app in a headless terminal, sent programmatic keypresses, and measured the time between input and screen update. For the counter, I sent 20 rapid keypresses and captured the `state_change` event timing. For the dashboard, I let the animation run and measured frame interval consistency.

**Frame-to-frame performance (after startup):**

| Metric | Ink | Nocterm |
|--------|-----|---------|
| Counter (per keypress) | 1.09ms mean, 1.85ms p95 | Sub-millisecond |
| Scrolling List (per scroll) | 2.18ms mean | Smooth, no lag |
| Dashboard (animation interval) | 101.1ms (target: 100ms) | 100ms (target: 100ms) |

Once both frameworks are running, they're both fast enough. The 60fps target is 16.67ms per frame - both frameworks come in well under that.

**The key difference is startup**. If your TUI runs once and stays open for hours, the 12ms startup tax is negligible. If it runs hundreds of times a day (think: git hooks, CLI tools, scripts), those milliseconds compound.

---

### Deployment

| Aspect | Ink | Nocterm |
|--------|-----|---------|
| Runtime Required | Node.js v18+ | None |
| Files to Deploy | Hundreds (node_modules) | 1 binary |
| Install Complexity | `npm install` + resolve issues | Copy file |
| Cross-Platform | Ship matching Node.js | Compile per platform |

---

## Architecture Comparison

### Ink's Stack

```
┌─────────────────────────────────────────────────────────┐
│                   Your React Components                  │
└────────────────────────────┬────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────┐
│                   React Reconciler                       │
│            (Virtual DOM, Fiber, Suspense)                │
└────────────────────────────┬────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────┐
│                   Yoga Layout Engine                     │
│              (C++ Flexbox via WASM/FFI)                  │
└────────────────────────────┬────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────┐
│                   Terminal Output                        │
└─────────────────────────────────────────────────────────┘
```

Every state change crosses the JS-to-WASM boundary for Yoga layout calculations. That's an FFI call per layout node.

### Nocterm's Stack

```
┌─────────────────────────────────────────────────────────┐
│                   Your Components                        │
└────────────────────────────┬────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────┐
│                   Element Tree                           │
│              (Lifecycle, dirty tracking)                 │
└────────────────────────────┬────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────┐
│                  RenderObject Tree                       │
│        (Native Dart layout, BoxConstraints)              │
└────────────────────────────┬────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────┐
│                   Terminal Buffer                        │
│          (Cell diff, escape coalescing, sixel)           │
└─────────────────────────────────────────────────────────┘
```

Everything runs in Dart. No FFI boundaries. No runtime context switches.

---

## Code Side-by-Side

### A Simple Counter

**Ink**:
```typescript
import React, { useState } from "react";
import { Box, Text, useInput } from "ink";

const Counter = () => {
  const [count, setCount] = useState(0);

  useInput((input, key) => {
    if (key.return) setCount(c => c + 1);
  });

  return (
    <Box flexDirection="column" alignItems="center">
      <Text>Press Enter to increment</Text>
      <Text color="green" bold>Count: {count}</Text>
    </Box>
  );
};
```

**Nocterm**:
```dart
class Counter extends StatefulComponent {
  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  int count = 0;

  @override
  Component build(BuildContext context) {
    return KeyboardListener(
      onKey: (event) {
        if (event.key == LogicalKey.enter) {
          setState(() => count++);
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("Press Enter to increment"),
          Text("Count: $count",
               style: TextStyle(color: Colors.green, bold: true)),
        ],
      ),
    );
  }
}
```

If you know Flutter, you already know Nocterm. Same `StatefulComponent`, same `setState()`, same lifecycle methods.

If you know React, you already know Ink. Same hooks, same JSX patterns, same mental model.

### Layout

**Ink** uses CSS Flexbox:
```typescript
<Box flexDirection="row" justifyContent="space-between" padding={1}>
  <Box width="50%"><Text>Left</Text></Box>
  <Box width="50%"><Text>Right</Text></Box>
</Box>
```

**Nocterm** uses Flutter's constraint model:
```dart
Padding(
  padding: EdgeInsets.all(1),
  child: Row(
    children: [
      Expanded(child: Text("Left")),
      Expanded(child: Text("Right")),
    ],
  ),
)
```

Both are declarative. Both compose naturally. The mental models are different but equally expressive.

---

## What the Industry Is Doing

I'm not the only one thinking about TUI performance.

**OpenAI** is [migrating Codex CLI from Ink to Rust](https://github.com/openai/codex/discussions/1174). Their reasons: zero-dependency install, native performance, no garbage collector pauses.

**Anthropic** uses Ink for Claude Code but [rewrote the renderer](https://newsletter.pragmaticengineer.com/p/how-claude-code-is-built) for "fine-grained incremental updates." The default Ink rendering wasn't sufficient for their needs.

**Google's Gemini CLI** uses Ink. **GitHub Copilot CLI** uses Ink. The framework has proven itself for production applications.

But there's a pattern here: the most demanding applications either move away from Ink or heavily customize it.

---

## The Summary

| Metric | Ink | Nocterm |
|--------|-----|---------|
| First Frame (static) | 12.0ms | 0.37ms |
| First Frame (dashboard) | 14.0ms | 0.47ms |
| Interactive Frame | ~1-2ms | <1ms |
| Binary Size | 43.1 MB | 7.4 MB |
| Memory (RSS) | 102.4 MB | 18.9 MB |
| Runtime | Node.js | None |
| Layout Engine | Yoga (C++) | Native Dart |
| Component Model | React | Flutter |

---

## What I'm Building Next

Nocterm is still young. I'm working on:

- **Animation framework** - Implicit and explicit animations, just like Flutter
- **Focus management** - Tab navigation, focus scopes
- **Testing utilities** - `testNocterm()` with visual assertions
- **More components** - Tables, trees, forms

The TUI space is having a moment. Every major AI company is shipping terminal interfaces. Developer tools are getting richer. The terminal isn't going away - it's evolving.

I think Flutter's patterns are the right foundation for this evolution. The numbers suggest I might be onto something.

---

*Benchmarks run on January 30, 2025. All test applications and raw data available in [`benchmark/`](benchmark/).*

*Nocterm is open source. Contributions welcome.*
