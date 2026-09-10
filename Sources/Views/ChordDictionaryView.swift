import SwiftUI

struct ChordDictionaryView: View {
    @EnvironmentObject var state: AppState
    @State private var root: PitchClass = .c
    @State private var quality: ChordQuality = .major7
    @State private var inversion: Int = 0
    @State private var octave: Int = 3

    private var chord: Chord { Chord(root: root, quality: quality, inversion: inversion) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Chord Dictionary").font(.title2.bold())

                HStack(spacing: 16) {
                    Picker("Root", selection: $root) {
                        ForEach(PitchClass.allCases) { Text($0.sharpName).tag($0) }
                    }.frame(width: 110)
                    Picker("Quality", selection: $quality) {
                        ForEach(ChordQuality.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .frame(width: 200)
                    .onChange(of: quality) { _, _ in inversion = 0 }
                    Stepper("Inversion: \(inversion)", value: $inversion,
                            in: 0...(max(0, chord.quality.intervals.count - 1)))
                    Button {
                        AudioEngine.shared.playChord(chord.notes(octave: octave))
                    } label: { Label("Play", systemImage: "play.fill") }
                    Button {
                        AudioEngine.shared.playSequence(chord.notes(octave: octave), noteDuration: 0.3)
                    } label: { Label("Arpeggiate", systemImage: "waveform.path") }
                }

                summaryCard

                PianoView(startNote: 48, octaves: 3,
                          highlightedPitchClasses: Set(chord.pitchClasses),
                          rootPitchClass: root,
                          highlightedNotes: Set(chord.notes(octave: octave).map(\.midi)),
                          labelStyle: .noteNames)
                    .frame(height: 130)

                inversionsCard
                familyCard
            }
            .padding(22)
        }
        .navigationTitle("Chord Dictionary")
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(chord.symbol()).font(.largeTitle.bold())
            HStack(spacing: 28) {
                labelled("Notes", chord.noteNames().joined(separator: " · "))
                labelled("Formula", quality.formula)
                labelled("Intervals", intervalNames)
            }
            if inversion > 0 {
                Text("Bass note: \(chord.bassPitchClass.sharpName) (\(ordinal(inversion)) inversion)")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.4)))
    }

    private var inversionsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Inversions").font(.headline)
            ForEach(Array(0..<chord.quality.intervals.count), id: \.self) { inv in
                let c = Chord(root: root, quality: quality, inversion: inv)
                HStack {
                    Text(inv == 0 ? "Root position" : "\(ordinal(inv)) inversion")
                        .frame(width: 140, alignment: .leading)
                    Text(c.notes(octave: octave).map { $0.name(withOctave: true) }.joined(separator: " – "))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button { AudioEngine.shared.playChord(c.notes(octave: octave)) } label: {
                        Image(systemName: "play.circle")
                    }.buttonStyle(.borderless)
                }
                .font(.callout).padding(.vertical, 2)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.4)))
    }

    private var familyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Same root, other qualities").font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 6)], spacing: 6) {
                ForEach(ChordQuality.allCases) { q in
                    Button {
                        quality = q; inversion = 0
                        AudioEngine.shared.playChord(Chord(root: root, quality: q).notes(octave: octave))
                    } label: {
                        Text(root.sharpName + q.symbolSuffix)
                            .frame(maxWidth: .infinity)
                    }
                    .tint(q == quality ? .accentColor : nil)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.4)))
    }

    private var intervalNames: String {
        var out: [String] = []
        var prev = 0
        for semi in quality.intervals {
            if semi == 0 { prev = 0; continue }
            out.append(Interval(semitones: semi - prev).shortName)
            prev = semi
        }
        return out.joined(separator: " ")
    }

    private func labelled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.callout)
        }
    }

    private func ordinal(_ n: Int) -> String {
        switch n {
        case 1: return "1st"; case 2: return "2nd"; case 3: return "3rd"
        default: return "\(n)th"
        }
    }
}
