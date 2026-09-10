import SwiftUI
import UniformTypeIdentifiers

struct ProgressionView: View {
    @EnvironmentObject var state: AppState
    @State private var showExporter = false
    @State private var midiDocument = MIDIDocument(data: Data())

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                controls

                if let progression = state.progression, !progression.chords.isEmpty {
                    chordRow(progression)
                    detailTable(progression)
                    PianoView(
                        startNote: 48, octaves: 3,
                        highlightedPitchClasses: currentChordPitchClasses(progression),
                        rootPitchClass: currentChordRoot(progression),
                        labelStyle: .noteNames,
                        key: state.key
                    )
                    .frame(height: 120)
                } else {
                    nonHeptatonicNotice
                }

                exportPanel
            }
            .padding(22)
        }
        .navigationTitle("Chord Progressions")
        .fileExporter(isPresented: $showExporter, document: midiDocument,
                      contentType: .midi, defaultFilename: state.suggestedFileName) { _ in }
    }

    // MARK: Sections

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(state.key.name).font(.title2.bold())
                Text("Diatonic chords: " + state.key.diatonicChords(sevenths: state.options.useSevenths)
                    .map(\.roman).joined(separator: "  "))
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                state.isPlaying ? state.stopPlayback() : state.playProgression()
            } label: {
                Label(state.isPlaying ? "Stop" : "Play", systemImage: state.isPlaying ? "stop.fill" : "play.fill")
                    .frame(width: 74)
            }
            .keyboardShortcut(.return, modifiers: [])
            Button { state.regenerate() } label: {
                Label("Generate", systemImage: "sparkles")
            }
            .keyboardShortcut("g", modifiers: .command)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 18) {
                Picker("Style", selection: $state.options.style) {
                    ForEach(GenerationStyle.allCases) { Text($0.rawValue).tag($0) }
                }
                .frame(maxWidth: 260)
                .onChange(of: state.options.style) { _, _ in state.regenerate() }

                Stepper(value: Binding(get: { state.options.length },
                                       set: { state.setLength($0) }), in: 2...16) {
                    Text("Length: \(state.options.length) chords")
                }
            }

            HStack(spacing: 20) {
                Toggle("7th chords", isOn: $state.options.useSevenths)
                    .onChange(of: state.options.useSevenths) { _, _ in state.regenerate() }
                Toggle("Inversions", isOn: $state.options.allowInversions)
                    .onChange(of: state.options.allowInversions) { _, _ in state.regenerate() }
                Toggle("Borrowed chords", isOn: $state.options.allowBorrowed)
                    .onChange(of: state.options.allowBorrowed) { _, _ in state.regenerate() }
                Toggle("Secondary dominants", isOn: $state.options.allowSecondaryDominants)
                    .onChange(of: state.options.allowSecondaryDominants) { _, _ in state.regenerate() }
            }
            .toggleStyle(.checkbox)

            HStack(spacing: 20) {
                Toggle("End with cadence", isOn: $state.options.endWithCadence)
                    .onChange(of: state.options.endWithCadence) { _, _ in state.regenerate() }
                Toggle("Start on tonic", isOn: $state.options.startOnTonic)
                    .onChange(of: state.options.startOnTonic) { _, _ in state.regenerate() }
                Toggle("Arpeggiate playback", isOn: $state.arpeggiatePlayback)
                Toggle("Use rhythm in playback", isOn: $state.useRhythmInPlayback)
            }
            .toggleStyle(.checkbox)

            HStack(spacing: 18) {
                HStack {
                    Text("Tempo").font(.callout)
                    Slider(value: $state.playbackTempo, in: 50...200, step: 1).frame(width: 180)
                    Text("\(Int(state.playbackTempo)) BPM").monospacedDigit().font(.callout)
                }
                HStack {
                    Text("Beats / chord").font(.callout)
                    Stepper(value: $state.beatsPerChord, in: 1...8, step: 1) {
                        Text("\(Int(state.beatsPerChord))").monospacedDigit()
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.5)))
    }

    private var nonHeptatonicNotice: some View {
        let parent = state.scaleType.isMinorish
            ? Key(tonic: state.tonic, scale: .naturalMinor)
            : Key(tonic: state.key.equivalentMajorRoot, scale: .major)
        return VStack(alignment: .leading, spacing: 10) {
            Label("Diatonic progressions need a 7-note scale", systemImage: "info.circle")
                .font(.headline)
            Text("“\(state.scaleType.rawValue)” has \(state.scaleType.intervals.count) notes, so it has no full set "
                 + "of diatonic triads to draw chords from. Switch to a heptatonic scale to generate progressions.")
                .foregroundStyle(.secondary)
            HStack {
                Button("Use \(parent.shortName)") {
                    state.tonic = parent.tonic
                    state.scaleType = parent.scale
                    state.regenerate()
                }
                Button("Use \(state.tonic.sharpName) Major") {
                    state.scaleType = .major
                    state.regenerate()
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.5)))
    }

    private func chordRow(_ progression: Progression) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(progression.chords.enumerated()), id: \.element.id) { index, pc in
                    ChordCard(
                        pc: pc,
                        key: progression.key,
                        isPlaying: state.playingChordIndex == index,
                        onTap: {
                            AudioEngine.shared.playChord(pc.chord.notes(octave: 3))
                        },
                        onReroll: { state.rerollChord(at: index) },
                        onLock: { state.toggleLock(at: index) }
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func detailTable(_ progression: Progression) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(progression.chords.enumerated()), id: \.element.id) { index, pc in
                HStack {
                    Text("\(index + 1)").frame(width: 24, alignment: .trailing)
                        .foregroundStyle(.secondary).monospacedDigit()
                    Text(pc.roman).frame(width: 74, alignment: .leading).bold()
                    Text(pc.chord.symbol(in: progression.key)).frame(width: 90, alignment: .leading)
                    Text(pc.chord.noteNames(in: progression.key).joined(separator: " · "))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(pc.function.rawValue)
                        .font(.caption).padding(.horizontal, 7).padding(.vertical, 2)
                        .background(functionColor(pc.function).opacity(0.25), in: Capsule())
                    if pc.borrowed { tag("borrowed", .purple) }
                    if pc.secondaryOf != nil { tag("secondary V", .blue) }
                }
                .font(.callout)
                .padding(.vertical, 6)
                .background(state.playingChordIndex == index ? Color.accentColor.opacity(0.12) : .clear)
                Divider()
            }
        }
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.4)))
    }

    private var exportPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MIDI Export").font(.headline)
            HStack(spacing: 18) {
                Toggle("Chords", isOn: $state.midiOptions.includeChords)
                Toggle("Bass", isOn: $state.midiOptions.includeBass)
                Toggle("Arpeggio", isOn: $state.midiOptions.includeArpeggio)
                Toggle("Apply rhythm", isOn: $state.midiOptions.applyRhythm)
                Toggle("Humanize", isOn: $state.midiOptions.humanize)
            }
            .toggleStyle(.checkbox)
            HStack {
                Button {
                    midiDocument = MIDIDocument(data: state.makeMIDIData())
                    showExporter = true
                } label: {
                    Label("Export .mid…", systemImage: "square.and.arrow.up")
                }
                .disabled(state.progression == nil)
                Text("Exports a Standard MIDI File (format 1) at \(Int(state.playbackTempo)) BPM.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.5)))
    }

    // MARK: Helpers

    private func tag(_ text: String, _ color: Color) -> some View {
        Text(text).font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.22), in: Capsule())
    }

    private func functionColor(_ f: HarmonicFunction) -> Color {
        switch f {
        case .tonic: return .green
        case .predominant: return .orange
        case .dominant: return .red
        }
    }

    private func currentChordPitchClasses(_ p: Progression) -> Set<PitchClass> {
        guard let i = state.playingChordIndex ?? (p.chords.isEmpty ? nil : 0),
              i < p.chords.count else { return [] }
        return Set(p.chords[i].chord.pitchClasses)
    }

    private func currentChordRoot(_ p: Progression) -> PitchClass? {
        guard let i = state.playingChordIndex ?? (p.chords.isEmpty ? nil : 0),
              i < p.chords.count else { return nil }
        return p.chords[i].chord.root
    }
}

struct ChordCard: View {
    let pc: ProgressionChord
    let key: Key
    let isPlaying: Bool
    let onTap: () -> Void
    let onReroll: () -> Void
    let onLock: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Text(pc.roman).font(.headline)
            Text(pc.chord.symbol(in: key)).font(.title3.bold())
            Text(pc.chord.noteNames(in: key).joined(separator: "\n"))
                .font(.caption2).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 10) {
                Button(action: onReroll) { Image(systemName: "die.face.5") }
                    .disabled(pc.locked)
                Button(action: onLock) {
                    Image(systemName: pc.locked ? "lock.fill" : "lock.open")
                }
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
        .frame(width: 108, height: 148)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isPlaying ? Color.accentColor.opacity(0.25) : Color.gray.opacity(0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isPlaying ? Color.accentColor : .clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

struct MIDIDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.midi] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
