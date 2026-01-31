# Why I Built a TUI Framework in Dart (And Benchmarked It Against Ink)

Claude Code, GitHub Copilot, Gemini CLI, Warp, Ghostty - in the past year, every major tech company has shipped a rich terminal interface. After years of simple `print()` statements, we're seeing React-style components, animations, and complex layouts right in our terminals.

This trend raises an interesting question: what's the best foundation for building these interfaces? When I started building [Nocterm](https://github.com/nocterm/nocterm), I had a hypothesis: Flutter's rendering architecture—the same engine powering millions of mobile apps—could work beautifully for terminals too.

This post is about that hypothesis. I built equivalent test applications in both Ink (the React-based TUI framework with 34k+ GitHub stars) and Nocterm, then measured everything I could. Here's what I found.

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

Both implementations follow each framework's recommended patterns: React hooks for Ink, StatefulComponents for Nocterm. Same visual output. Same functionality.

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
                                          32x faster startup
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
- Yoga layout engine initialization (C++ via native bindings)
- V8 JIT warmup

Nocterm bundles its runtime into the binary via AOT compilation. No separate interpreter needs to start.

---

### Binary Size

> **How I measured this**: For Nocterm, I compiled with `dart compile exe`. For Ink, I packaged into a standalone binary with `bun build --compile` - this is the fairest apples-to-apples comparison (both produce single executables with no runtime required).

```
Standalone Binary Size
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Ink (Bun)   ████████████████████████████████████████████████████████ 56 MB
Nocterm     ███████ 7.4 MB
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                               7.5x smaller
```

| Deployment Model | Ink | Nocterm |
|------------------|-----|---------|
| Standalone binary | 56 MB (Bun) | 7.4 MB |
| With runtime | 43 MB (node_modules) + Node.js | N/A (always standalone) |

The 56 MB for Ink includes the entire Bun runtime. The 7.4 MB for Nocterm includes the Dart runtime—Dart's AOT compiler eliminates unused code more aggressively than bundling a JavaScript runtime.

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

The ~100 MB baseline for Ink reflects Node.js + V8 + React + Yoga—this is the cost of the runtime stack, before your application code runs.

Nocterm's ~19 MB is the full Dart runtime + your app. For a TUI framework, that's quite lean.

---

### Frame Time (Maximum FPS Test)

> **How I measured this**: I disabled frame rate limiting and ran a tight loop triggering state changes as fast as possible for 3 seconds. I ran 10 iterations for each framework.

**Result: Ink is ~13% faster at raw rendering.**

| Framework | Average FPS | Mean Frame Time | Variance |
|-----------|-------------|-----------------|----------|
| Ink | 8,193 | 122µs | ±10% across runs |
| Nocterm | 7,242 | 135µs | ±1% across runs |

Ink wins this benchmark. But here's why it doesn't matter much:

Both frameworks render frames over 100x faster than needed for 60fps (16,667µs per frame). At 7,000+ FPS, you're not going to see the difference between 122µs and 135µs frames.

What's more interesting is the variance: Nocterm is remarkably consistent (±1%), while Ink varies ±10% run-to-run—likely due to Node.js JIT warmup and garbage collection. For long-running applications like animated dashboards, this consistency might matter more than raw speed. For typical TUIs (forms, menus, editors), both are more than fast enough.

---

### Deployment

| Aspect | Ink | Nocterm |
|--------|-----|---------|
| Runtime Required | Node.js v18+ (widely installed) | None (self-contained) |
| Distribution | npm package or Bun standalone | Single binary per OS/arch |
| Install | `npm install` | Copy file |
| Cross-Platform | Node.js handles it | Compile for each target |

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

Every state change crosses the JavaScript-to-native boundary for Yoga layout calculations—an FFI call for each layout node.

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

Everything runs in Dart. No FFI boundaries to cross.

### Why Flutter's Three-Tree Architecture?

Flutter uses three synchronized trees:

```
Widget Tree       →    Element Tree    →    RenderObject Tree
(what you write)      (lifecycle mgmt)     (layout & paint)
```

*(Flutter calls these "Widgets"; Nocterm uses "Components" - same concept.)*

This separation is why Nocterm can be fast despite being newer:
- The Element tree diffs efficiently (like React's reconciler)
- The RenderObject tree skips layout for unchanged subtrees
- Dirty tracking happens at the right granularity

When you write a `StatefulComponent` in Nocterm, you get the same lifecycle, the same `setState()`, the same rebuild semantics as Flutter's `StatefulWidget`. It's a proven architecture.

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

Ink powers major CLI tools: Google's Gemini CLI, GitHub Copilot CLI, and many others. With 34k+ GitHub stars and years of production use, it's proven technology.

That said, some teams are exploring alternatives. OpenAI is [migrating Codex CLI to Rust](https://github.com/openai/codex/discussions/1174) for zero-dependency deployment. Anthropic uses Ink for Claude Code but [rewrote the renderer](https://newsletter.pragmaticengineer.com/p/how-claude-code-is-built) for more control over updates.

Different teams optimize for different goals—there's no single right answer.

---

## When to Choose Which

**Choose Ink if:**
- Your team already knows React and TypeScript
- You need access to the npm ecosystem (thousands of packages)
- You're building a long-running application where startup time doesn't matter
- You want the most mature, battle-tested option (5+ years in production)

**Choose Nocterm if:**
- You're building CLI tools that run frequently (git hooks, build scripts, dev tools)
- Deployment simplicity matters (single binary, no runtime)
- Your team already knows Flutter/Dart
- Memory footprint is a concern (embedded systems, resource-constrained environments)

**Consider either for:**
- Interactive dashboards
- Form-based applications
- Any TUI where both startup time and ecosystem don't dominate the decision

---

## Benchmark Limitations

These tests measure specific scenarios on a single platform (macOS arm64, Apple M4 Pro). Results may differ on Linux/Windows, older hardware, or with different terminal emulators.

Real-world performance depends on your specific use case—startup time matters more for short-lived CLI tools, while frame time matters more for long-running dashboards. Neither framework will be your bottleneck for typical TUI applications.

---

## The Summary

| Metric | Ink | Nocterm | Winner |
|--------|-----|---------|--------|
| First Frame (startup) | 12.0ms | 0.37ms | Nocterm (32x) |
| Frame Time (max FPS) | 122µs | 135µs | Ink (13% faster) |
| Binary Size (standalone) | 56 MB | 7.4 MB | Nocterm (7.5x) |
| Memory (RSS) | 102.4 MB | 18.9 MB | Nocterm (5.4x) |
| Ecosystem | npm (millions of packages) | pub.dev (smaller) | Ink |
| Runtime | Node.js required | None | Nocterm |
| Component Model | React | Flutter | Tie (preference) |

---

## Try It Yourself

All the benchmark code is in this repo. Run the tests yourself:

```bash
# Clone and run Nocterm benchmarks
cd benchmark/apps/01_static_layout/nocterm
dart compile exe bin/app.dart -o app_exe
./app_exe

# Run Ink benchmarks
cd benchmark/apps/01_static_layout/ink
npm install && npm run build
node dist/index.js
```

If you want to build something with Nocterm:

```bash
dart pub add nocterm
```

Check out the [`example/`](example/) folder for patterns: counters, forms, layouts, keyboard handling.

---

*Nocterm is still young (Ink has 5+ years on us). Contributions welcome.*

*Benchmarks ran on January 30, 2025. Environment: Apple M4 Pro, 48GB RAM, macOS arm64. All test applications and raw data available in [`benchmark/`](benchmark/).*
