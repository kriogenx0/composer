import SwiftUI

struct PianoStudioView: View {
    @EnvironmentObject var state: AppState
    @State private var highlightScale = true
    @State private var showChord: ChordQuality? = nil
    @State private var chordRoot: PitchClass = .c
    @State private var labelStyle: PianoView.LabelStyle = .noteNames
    @State private var octaveBase = 4
    @State private var pressed: Set<Int> = []
    @FocusState private var focused: Bool

    // Computer-keyboard → semitone offset, one octave (a…k white, w e t y u black).
    private let keyMap: [Character: Int] = [
        "a": 0, "w": 1, "s": 2, "e": 3, "d": 4, "f": 5, "t": 6,
        "g": 7, "y": 8, "h": 9, "u": 10, "j": 11, "k": 12, "o": 13, "l": 14,
    ]

    private var scale: Scale { Scale(root: state.tonic, type: state.scaleType) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Piano").font(.title2.bold())
            Text("Click keys, or play your computer keyboard (A–L = white keys, W E T Y U = black). "
                 + "Click the panel first so it has keyboard focus.")
                .font(.callout).foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Toggle("Highlight working scale", isOn: $highlightScale)
                Picker("Labels", selection: $labelStyle) {
                    Text("Note names").tag(PianoView.LabelStyle.noteNames)
                    Text("Scale degrees").tag(PianoView.LabelStyle.degrees)
                    Text("None").tag(PianoView.LabelStyle.none)
                }.frame(width: 200)
                Stepper("Octave: \(octaveBase)", value: $octaveBase, in: 1...6)
            }
            .toggleStyle(.checkbox)

            HStack(spacing: 10) {
                Text("Show chord:").font(.callout)
                Picker("root", selection: $chordRoot) {
                    ForEach(PitchClass.allCases) { Text($0.sharpName).tag($0) }
                }.labelsHidden().frame(width: 80)
                Picker("quality", selection: Binding(get: { showChord ?? .major },
                                                     set: { showChord = $0 })) {
                    ForEach(ChordQuality.allCases) { Text($0.rawValue).tag($0) }
                }.labelsHidden().frame(width: 170)
                Button("Clear") { showChord = nil }
                if let q = showChord {
                    Button {
                        AudioEngine.shared.playChord(Chord(root: chordRoot, quality: q).notes(octave: octaveBase - 1))
                    } label: { Image(systemName: "play.circle") }
                }
            }

            PianoView(startNote: (octaveBase) * 12, octaves: 3,
                      highlightedPitchClasses: highlightedPCs,
                      rootPitchClass: showChord != nil ? chordRoot : (highlightScale ? state.tonic : nil),
                      highlightedNotes: pressed,
                      labelStyle: labelStyle,
                      key: state.key)
                .frame(height: 190)
                .focusable()
                .focused($focused)
                .focusEffectDisabled()
                .onKeyPress(phases: [.down, .up]) { press in
                    handleKey(press)
                }
                .onAppear { focused = true }

            legend
            Spacer()
        }
        .padding(22)
        .navigationTitle("Piano")
        .onAppear { chordRoot = state.tonic }
    }

    private var highlightedPCs: Set<PitchClass> {
        if let q = showChord { return Set(Chord(root: chordRoot, quality: q).pitchClasses) }
        return highlightScale ? Set(scale.pitchClasses) : []
    }

    private var legend: some View {
        HStack(spacing: 18) {
            legendDot(.orange, "Root")
            legendDot(Color.accentColor.opacity(0.5), showChord != nil ? "Chord tone" : "In scale")
            legendDot(Color.accentColor, "Playing")
        }
        .font(.caption)
    }

    private func legendDot(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 14, height: 14)
            Text(text)
        }
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        guard let ch = press.characters.lowercased().first,
              let offset = keyMap[ch] else { return .ignored }
        let midi = octaveBase * 12 + offset
        switch press.phase {
        case .down:
            if !pressed.contains(midi) {
                pressed.insert(midi)
                AudioEngine.shared.noteOn(midi, velocity: 96)
            }
        case .up:
            pressed.remove(midi)
            AudioEngine.shared.noteOff(midi)
        default:
            break
        }
        return .handled
    }
}
