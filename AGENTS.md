# AGENTS.md — Composer

Composer is a native SwiftUI macOS app for learning music theory and sketching music: chord progressions, rhythm, MIDI export, circle of fifths, scales, a chord dictionary, and a piano. It has no third-party dependencies. See [README.md](README.md) for the feature list.

## Commands

Requires Xcode 15+ and XcodeGen (`brew install xcodegen`). There is no Makefile yet.

- `xcodegen generate`: write `Composer.xcodeproj` from `project.yml` (the project is git-ignored).
- `xcodebuild -project Composer.xcodeproj -scheme Composer -configuration Debug build`: headless build.
- `open Composer.xcodeproj`, then ⌘R, to run.

There is no test target yet.

## Layout

- `Sources/Theory/`: pure music-theory models (`Note`, `Interval`, `Scale`, `Chord`, `Key`, `Progression`, `Rhythm`). Keep these free of UI and audio code.
- `Sources/Audio/`: `AVAudioEngine` playback using the system General MIDI soundbank, plus the metronome.
- `Sources/MIDI/`: the hand-written Standard MIDI File writer and exporter.
- `Sources/Views/`: one view per section; reusable pieces are in `Views/Components/`.
- `Sources/AppState.swift`: shared app state.

## Conventions

- Edit `project.yml`, not the generated project. New files under `Sources/` are picked up on `xcodegen generate`.
- Theory code should stay deterministic and side-effect free, so it can get unit tests later.

## Design principles

Follow the [design principles](docs/rules/design-principles.md) for any UI work.

## After changing code

1. `xcodegen generate`
2. `xcodebuild -project Composer.xcodeproj -scheme Composer -configuration Debug build`

Commit messages are one short, imperative line, like the existing history.
