# Mouse Cursor Control Research

## Overview

This document summarizes research into controlling the mouse pointer cursor from a terminal TUI application, with the goal of providing visual feedback (e.g., I-beam for text, pointer for buttons) during user interaction.

## The Challenge

Terminal applications run as child processes of the terminal emulator. The **terminal owns the window** and therefore controls the mouse cursor. Our TUI app can only communicate via stdin/stdout escape sequences.

```
┌─────────────────────────────────┐
│  Terminal (Warp/Kitty/iTerm)    │  ← Window owner, controls cursor
│  ┌───────────────────────────┐  │
│  │  TUI app (child process)   │  │  ← Cannot directly control cursor
│  │  └── stdin/stdout ────────│──│──── Only communication channel
│  └───────────────────────────┘  │
└─────────────────────────────────┘
```

---

## Approach 1: OSC 22 Escape Sequence (Recommended)

**Format:** `ESC ] 22 ; <shape> ESC \`

### Supported Shapes (CSS cursor names)
- `default` - Normal arrow
- `pointer` - Hand/link cursor
- `text` - I-beam for text selection
- `crosshair` - Precision selection
- `grab` / `grabbing` - Draggable items
- `move` - Moving something
- `not-allowed` - Disabled
- `wait` - Loading
- `cell`, `copy`, `help`, `zoom-in`, `zoom-out`, resize cursors, etc.

### Terminal Support

| Terminal | OSC 22 Support |
|----------|----------------|
| ✅ Kitty | Full support (30 CSS cursor names) |
| ✅ foot | Supported |
| ✅ xterm | Supported (original proposal) |
| ✅ Alacritty | Supported (enable with `terminal.osc22`) |
| ✅ WezTerm | Supported |
| ❌ **Warp** | Not supported |
| ❌ macOS Terminal.app | Not supported |
| ❓ iTerm2 | Unknown |

### Implementation

```dart
// Set cursor to pointer (hand)
stdout.write('\x1b]22;pointer\x1b\\');

// Set cursor to I-beam (text)
stdout.write('\x1b]22;text\x1b\\');

// Reset to default
stdout.write('\x1b]22;default\x1b\\');
```

### Demo
See `example/mouse_pointer_demo.dart`

---

## Approach 2: CGS Private APIs (macOS only, hacky)

Uses undocumented CoreGraphics Services APIs to control the cursor system-wide.

### Key Functions

```c
// Get connection to WindowServer
CGSConnectionID CGSMainConnectionID(void);

// Enable background cursor control (the magic trick!)
CGSSetConnectionProperty(cid, cid, CFSTR("SetsCursorInBackground"), kCFBooleanTrue);

// Set cursor type
CGSSetSystemDefinedCursor(cid, cursorId);

// Show/hide cursor
CGSShowCursor(cid);
CGSHideCursor(cid);
```

### Cursor IDs

| ID | Cursor |
|----|--------|
| 0 | Arrow |
| 1 | I-Beam |
| 5 | Move |
| 7 | Wait/Busy |
| 10 | Pointing Hand |
| 11 | Open Hand |
| 12 | Closed Hand |

### Pros
- Works in **any terminal** including Warp
- System-wide cursor control

### Cons
- **Private APIs** - will get rejected from Mac App Store
- May break in future macOS versions
- Cursor resets when switching tabs/windows (requires focus tracking to reapply)
- Only works on macOS

### Focus Tracking

To handle cursor reset on tab switch, use xterm focus reporting:

```dart
// Enable focus reporting
stdout.write('\x1b[?1004h');

// Terminal sends:
// ESC [ I  - when focus gained
// ESC [ O  - when focus lost

// On focus gained, reapply cursor
```

### Demos
- `example/cgs_cursor_demo.dart` - Basic CGS cursor control
- `example/cgs_cursor_focus_demo.dart` - With focus tracking

---

## Approach 3: Text Cursor Shape (DECSCUSR)

This controls the **text cursor** (blinking block/bar/underline), not the mouse pointer.

**Format:** `ESC [ N SP q` (where SP is a literal space)

| Value | Cursor Style |
|-------|-------------|
| 0, 1 | Blinking block |
| 2 | Steady block |
| 3 | Blinking underline |
| 4 | Steady underline |
| 5 | Blinking bar (I-beam) |
| 6 | Steady bar (I-beam) |

Widely supported in all terminals. Used by Vim for mode indication.

### Demo
See `example/cursor_shape_demo.dart`

---

## Recommendation

### For Maximum Compatibility
1. Use **OSC 22** where supported (detect via query: `ESC ] 22 ; ?pointer ESC \`)
2. **Gracefully degrade** in unsupported terminals (no cursor changes)
3. Consider the CGS approach only for macOS-specific builds distributed outside App Store

### For Warp Specifically
- File a feature request for OSC 22 support at github.com/warpdotdev/Warp
- The CGS private API approach works but requires focus tracking

---

## Files Created

| File | Description |
|------|-------------|
| `example/cursor_shape_demo.dart` | Text cursor shape (DECSCUSR) |
| `example/mouse_pointer_demo.dart` | OSC 22 mouse pointer (Kitty) |
| `example/cgs_cursor_demo.dart` | CGS private APIs (macOS) |
| `example/cgs_cursor_focus_demo.dart` | CGS with focus tracking |

---

## References

- [Kitty Pointer Shapes](https://sw.kovidgoyal.net/kitty/pointer-shapes/)
- [VT510 DECSCUSR](https://vt100.net/docs/vt510-rm/DECSCUSR.html)
- [CGSInternal Headers](https://github.com/NUIKit/CGSInternal)
- [Mousecape (CGS cursor manager)](https://github.com/alexzielenski/Mousecape)
- [XTerm Control Sequences](https://invisible-island.net/xterm/ctlseqs/ctlseqs.html)
