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

**Environment**: Apple M1 Pro, 32GB RAM, macOS, Terminal size 80x24

---

## The Numbers

### Startup Time

```
First Frame Render Time
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Ink     ████████████████████████████████████████ 12.02ms
Nocterm █ 0.32ms
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                               37x difference
```

| Framework | Mean | Min | Max | Std Dev |
|-----------|------|-----|-----|---------|
| Ink | 12.02ms | 11.84ms | 12.11ms | 0.12ms |
| Nocterm | 0.32ms | 0.31ms | 0.34ms | 0.01ms |

Where does the 12ms go in Ink?
- Node.js runtime initialization
- Module resolution and loading
- React reconciler setup
- Yoga layout engine initialization (C++ → WASM bridge)
- V8 JIT warmup

Nocterm is AOT-compiled. The binary loads, runs, and renders. There's no runtime to start.

### Binary Size

```
Deployment Size
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Ink     ████████████████████████████████████████ 43.1 MB
Nocterm ███████ 7.4 MB
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                               5.8x difference
```

| Framework | Size | What's Included |
|-----------|------|-----------------|
| Ink | 43.1 MB | node_modules (React, Ink, Yoga, chalk, dozens of deps) |
| Nocterm | 7.4 MB | Single AOT binary (everything included) |

The Ink number doesn't include Node.js itself. If you need to bundle a standalone executable (using pkg or nexe), add another 40+ MB for the Node runtime.

### Memory

| Metric | Ink | Nocterm |
|--------|-----|---------|
| Heap | 18.1 MB | ~2 MB |
| RSS (Total) | 92.7 MB | ~15 MB |

92 MB is the baseline for *any* Ink application. That's Node.js + V8 + React + Yoga before your code runs.

### Deployment

| Aspect | Ink | Nocterm |
|--------|-----|---------|
| Runtime Required | Node.js v18+ | None |
| Files to Deploy | Hundreds | 1 |
| Cross-Platform | Ship matching Node.js | Compile per platform |

### Interactive Frame Times

The startup numbers are one thing, but what about actual interactive use? I ran each app in a headless terminal, sent programmatic input, and measured response times.

**First frame (time to interactive):**

| App | Nocterm | Ink | Speedup |
|-----|---------|-----|---------|
| Counter | 0.81ms | 10.19ms | 12.5x |
| Scrolling List | 0.57ms | 10.0ms | 17.7x |
| Dashboard | 0.50ms | 13.85ms | 27.7x |

The more complex the app, the bigger the gap. The dashboard (with multiple animations, progress bars, and a scrolling log) shows nearly 28x faster time-to-first-frame.

**Frame-to-frame performance:**

Once both frameworks are running, they're both fast enough. Ink's counter updates take ~1ms per keystroke. The scrolling list renders each scroll in ~2ms. Both frameworks hit their animation targets accurately.

This is expected. The startup cost is where Node.js + React + Yoga pay their tax. Once everything is initialized and JIT-warmed, JavaScript is plenty fast for terminal rendering.

**The practical difference**: If your TUI starts 100 times a day, those 10-14ms add up. If it's a long-running application, startup matters less.

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
import React, { useState } from 'react';
import { Box, Text, useInput } from 'ink';

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
          Text('Press Enter to increment'),
          Text('Count: $count',
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
      Expanded(child: Text('Left')),
      Expanded(child: Text('Right')),
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
| First Frame (static) | 12.02ms | 0.32ms |
| First Frame (dashboard) | 13.85ms | 0.50ms |
| Interactive Frame | ~1-2ms | ~1-2ms |
| Binary Size | 43.1 MB | 7.4 MB |
| Memory (RSS) | ~100 MB | ~15 MB |
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
