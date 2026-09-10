import SwiftUI

struct ScaleExplorerView: View {
    @EnvironmentObject var state: AppState
    @State private var root: PitchClass = .c
    @State private var type: ScaleType = .major

    private var scale: Scale { Scale(root: root, type: type) }
    private var key: Key { Key(tonic: root, scale: type.isDiatonicMode ? type : .major) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Scales & Modes").font(.title2.bold())

                HStack(spacing: 16) {
                    Picker("Root", selection: $root) {
                        ForEach(PitchClass.allCases) { Text($0.name(in: key)).tag($0) }
                    }.frame(width: 120)
                    Picker("Scale", selection: $type) {
                        ForEach(ScaleType.allCases) { Text($0.rawValue).tag($0) }
                    }.frame(width: 260)
                    Button {
                        AudioEngine.shared.playSequence(scale.notes(fromOctave: 4), noteDuration: 0.32)
                    } label: { Label("Play ascending", systemImage: "play.fill") }
                    Button {
                        AudioEngine.shared.playSequence(scale.notes(fromOctave: 4).reversed(), noteDuration: 0.32)
                    } label: { Label("Descending", systemImage: "play.fill") }
                    Button("Use as working key") {
                        state.tonic = root
                        state.scaleType = type
                        state.regenerate()
                    }
                }
                .onAppear { root = state.tonic; type = state.scaleType }

                notesCard
                intervalCard

                PianoView(startNote: 48, octaves: 3,
                          highlightedPitchClasses: Set(scale.pitchClasses),
                          rootPitchClass: root,
                          labelStyle: .degrees,
                          key: key)
                    .frame(height: 130)

                if type.isDiatonicMode {
                    modeComparison
                }
                characteristics
            }
            .padding(22)
        }
        .navigationTitle("Scales & Modes")
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes").font(.headline)
            HStack(spacing: 10) {
                ForEach(Array(scale.pitchClasses.enumerated()), id: \.offset) { i, pc in
                    VStack(spacing: 3) {
                        Text(pc.name(in: key)).font(.title3.bold())
                        Text(type.degreeLabels[i]).font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(width: 52, height: 52)
                    .background(RoundedRectangle(cornerRadius: 8).fill(
                        i == 0 ? Color.orange.opacity(0.3) : Color.accentColor.opacity(0.15)))
                    .onTapGesture { AudioEngine.shared.play(midi: Note(pc, octave: 4).midi) }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.4)))
    }

    private var intervalCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Step pattern").font(.headline)
            HStack(spacing: 6) {
                ForEach(Array(type.stepPattern.enumerated()), id: \.offset) { _, interval in
                    Text(interval.stepSpelling)
                        .font(.callout.monospaced())
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(.quaternary))
                }
            }
            Text("W = whole step (2 semitones), H = half step (1 semitone).")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.4)))
    }

    private var modeComparison: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Modes of the parent major scale").font(.headline)
            let parentRoot = key.equivalentMajorRoot
            ForEach(Array(ScaleType.diatonicModes.enumerated()), id: \.offset) { i, mode in
                let modeRoot = Scale(root: parentRoot, type: .major).pitchClasses[i]
                HStack {
                    Text(mode.rawValue).frame(width: 190, alignment: .leading)
                        .fontWeight(mode == type ? .bold : .regular)
                    Text(Scale(root: modeRoot, type: mode).pitchClasses.map { $0.name(in: key) }.joined(separator: " "))
                        .foregroundStyle(.secondary).font(.callout)
                    Spacer()
                    Button {
                        AudioEngine.shared.playSequence(Scale(root: modeRoot, type: mode).notes(fromOctave: 4), noteDuration: 0.26)
                    } label: { Image(systemName: "play.circle") }.buttonStyle(.borderless)
                }
                .font(.callout)
                .padding(.vertical, 3)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.4)))
    }

    private var characteristics: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Character").font(.headline)
            Text(Self.descriptions[type] ?? "A \(type.intervals.count)-note scale.")
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.4)))
    }

    static let descriptions: [ScaleType: String] = [
        .major: "Bright, resolved, the reference scale of Western tonal music (Ionian mode).",
        .naturalMinor: "Dark and plaintive. Aeolian mode — the major scale started from its 6th degree.",
        .harmonicMinor: "Natural minor with a raised 7th, restoring a strong leading tone and the V–i cadence. Exotic ♭6→7 leap.",
        .melodicMinor: "Raised 6th and 7th ascending for smooth voice-leading to the tonic; jazz uses it in both directions.",
        .dorian: "Minor with a bright raised 6th. Folk, modal jazz, 'So What'. Less sombre than natural minor.",
        .phrygian: "Minor with a ♭2. Spanish/flamenco colour, metal. The ♭2→1 gives a strong downward pull.",
        .lydian: "Major with a ♯4. Floating, dreamlike, film-score wonder. No tension toward the tonic.",
        .mixolydian: "Major with a ♭7. Bluesy, dominant-flavoured; rock and Celtic music live here.",
        .locrian: "Diminished tonic (♭2 and ♭5). Unstable, rarely a tonal centre; used over m7♭5 chords.",
        .majorPentatonic: "Major scale without the 4th and 7th — no semitones, no dissonance. Ubiquitous in folk and pop melody.",
        .minorPentatonic: "Minor scale without the 2nd and ♭6. The backbone of blues, rock and guitar soloing.",
        .blues: "Minor pentatonic plus a chromatic ♭5 'blue note' for expressive bends.",
        .wholeTone: "Six notes a whole step apart. Symmetrical, ambiguous, dream sequences and Debussy.",
        .chromatic: "All twelve pitches. Used for passing tones and colour, not as a key centre.",
    ]
}
