# Composer

A native macOS app for learning music theory and sketching music. Built with SwiftUI,
no third-party dependencies. Audio playback uses the system General-MIDI soundbank via
`AVAudioEngine`; MIDI export is a hand-rolled Standard MIDI File writer.

## Build & run

Requires Xcode 15+ and [XcodeGen](https://github.com/yonyz/XcodeGen) (`brew install xcodegen`).

```sh
xcodegen generate          # writes Composer.xcodeproj from project.yml
open Composer.xcodeproj     # then ⌘R
# or headless:
xcodebuild -project Composer.xcodeproj -scheme Composer -configuration Debug build
```

The `.xcodeproj` is generated and git-ignored — edit `project.yml` and re-run `xcodegen`.

## What's inside

| Section | |
|---|---|
| **Chord Progressions** | Pick a key + scale/mode and a length (2–16). Generation styles: functional-harmony weighted walk, canned common progressions, pop loops, jazz ii–V–I chains, random diatonic. Options for 7th chords, extensions via quality, inversions, borrowed chords and secondary dominants. Lock or re-roll individual chords. Playback with tempo / beats-per-chord / arpeggiation. Roman numerals, chord symbols, note spellings and harmonic function are shown for every chord. |
| **Rhythm & Syncopation** | Time signatures (4/4, 3/4, 6/8, 9/8, 12/8, 5/4, 7/8), subdivisions down to sixteenths and triplets, a swing amount, and a **syncopation slider** that pushes on-beat hits onto neighbouring off-beats and ties them across the pulse. Editable step grid (click = toggle, ⌥-click = accent, ⇧-click = tie) plus preset grooves: tresillo, son/rumba clave, bossa, habanera, dembow, charleston, backbeat, four-on-the-floor, offbeat skank… The active pattern drives both playback and export. |
| **MIDI Export** | Standard MIDI File (format 1, 480 PPQ). Separate chord / bass / arpeggio tracks, the rhythm pattern applied per chord, optional humanised timing and velocity, tempo and time-signature meta events. |
| **Circle of Fifths** | Interactive two-ring wheel (major outer, relative minor inner). Click a key to see its signature, accidentals, relative/parallel minor, dominant and subdominant neighbours, and all diatonic triads (playable). Load any key straight into the working key. The current progression's roots are highlighted on the wheel. |
| **Scales & Modes** | Any root × 14 scale types. Notes with degree labels, W/H step pattern, a piano view coloured by scale degree, ascending/descending playback, a character note, and — for the diatonic modes — all seven modes of the parent scale side by side. |
| **Chord Dictionary** | Build any chord from root × 21 qualities × inversion. Formula, interval stack, note spellings, a piano diagram, every inversion, and one-click siblings on the same root. |
| **Piano** | A playable keyboard — mouse or computer keys (A–L white, W E T Y U black). Highlights the working scale or any chord you name; note-name or scale-degree labels. |
| **Ear Training** | Interval, chord-quality, cadence and scale-degree recognition with running score. |
| **Metronome** | 40–240 BPM, tap tempo, accented downbeat, selectable subdivision, visual beat lights. |
| **Polyrhythm** | A geometric wheel: concentric rings (1–5 voices), each split into 2–12 evenly-spaced dots, with a clock-style hand sweeping one turn per cycle and striking a ring as it passes each dot. Per-ring pitch / accent / mute, tempo, presets (2:3, 3:4, 3:5, 4:5, 5:7, 3:4:5…), and each ring's implied BPM. |
| **Reference** | Filterable cards — functional harmony, cadences, intervals, chord construction, key signatures, common progressions, rhythm terms, song forms, the modes ordered bright→dark — plus a glossary. |

Sections are grouped in the sidebar (Create / Explore / Practice / Learn). The working
key/scale picker at the bottom of the sidebar is shared across every section.

## Source layout

```
Sources/
  Theory/   Note, Interval, Scale, Chord, Key (signatures + diatonic harmony + circle of fifths),
            Progression (weighted generator), Rhythm (patterns, syncopation, swing)
  Audio/    AudioEngine (AVAudioUnitSampler playback), Metronome
  MIDI/     MIDIFile (SMF writer), MIDIExporter (progression + rhythm -> events)
  Views/    one SwiftUI view per section + reusable PianoView / StepGridView
```
