# Introibo

A free iOS app for traditional Catholics. 1962 Latin Mass, Divine Office, Rosary,
Stations of the Cross, Confession guide, Saints, Prayers, Schola Latina, Reference.

No accounts. No tracking. No ads. All data local.

---

## Project layout

```
prototype/          Working HTML/CSS/JS prototype — the source of truth for all
                    content, layout, and interaction. Open any .html file in a
                    browser at 430 px width to preview.
Introibo/           Swift (SwiftUI) iOS app — under active build.
project.yml         XcodeGen spec.
```

## Building the iOS app

Prerequisite: macOS with **Xcode 15+** and **XcodeGen** (`brew install xcodegen`).

```sh
xcodegen generate
open Introibo.xcodeproj
```

Build target: iOS 17.0+. Bundle ID: `app.introibo.Introibo`. No code signing required
for local builds.

## Prototype

The full working prototype is in `prototype/`. Open `prototype/today.html` in a
browser at mobile width (Chrome DevTools device mode → iPhone 14 Pro) to see all
ten screens as they render today.

## Status

Prototype: complete. Swift port: scaffold in progress. See commit history for
per-screen progress.
