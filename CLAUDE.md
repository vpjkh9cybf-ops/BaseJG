# Conventional Wisdom — working notes

An iPad contract bridge app (rubber & Chicago scoring, SAYC bidding, convention
drills). Swift Playgrounds project at `BridgeGame.swiftpm/`.

## File header stamps — do this on every edit

Every source file starts with a stamp line:

```swift
// Conventional Wisdom — modified YYYY-MM-DD HH:MM UTC
```

**Whenever you modify a file, update its stamp to the current UTC time**, so the
user can tell at a glance which files changed after pulling into Playgrounds.
Only bump the stamp on files whose contents you actually changed — an untouched
file keeps its older date, which is the whole point.

`Package.swift` is the exception to placement: `// swift-tools-version:` must
stay on line 1, so its stamp goes on line 2.

## Environment

- **Branch: `conventionalwisdom`.** Commit and push there.
- **There is no Swift toolchain in this container** — no compiler, no simulator.
  Code cannot be built or run here. The user pulls via Working Copy on iPad and
  Swift Playgrounds is the first thing that compiles it. So: verify by reading,
  check call sites by hand, and be explicit that a change is unverified. When a
  build error comes back, ask for the exact message plus file and line.
- Swift 6 strict concurrency; `GameState` is `@MainActor`.

## Swift Playgrounds constraints learned the hard way

- No `if` inside an `.alert` action builder — it is rejected at runtime. Use
  separate `.alert` modifiers bound to different booleans instead.
- Prefer non-`@ViewBuilder` helpers that bind locals then `return Group { ... }`
  over `@ViewBuilder` functions with leading `let` bindings.
- `Form` / `Group` ViewBuilders cap at 10 children; wrap sections in `Group`.

## Layout

iPad **landscape only** (`Package.swift` declares `[.pad]` and the two landscape
orientations). The table is a fixed 145pt score column plus West / centre / East
columns and a 13-card fan; it has no portrait or iPhone form. Card sizes derive
from the space each area is given (`CardView.explicitHeight`) rather than fixed
constants — keep it that way, or hands start overlapping the trick area again.

## Still open for App Store submission

App icon (no asset catalog exists), a real bundle identifier (currently the
placeholder `com.bridge.game`), the display name in `Package.swift` (still
`BridgeGame`), and a developer account plus App Store Connect record.
