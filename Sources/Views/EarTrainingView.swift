import SwiftUI

struct EarTrainingView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case intervals = "Intervals"
        case chordQuality = "Chord quality"
        case cadence = "Cadences"
        case scaleDegree = "Scale degree"
        var id: String { rawValue }
    }

    @EnvironmentObject var state: AppState
    @State private var mode: Mode = .intervals
    @State private var prompt: [Note] = []
    @State private var answer = ""
    @State private var choices: [String] = []
    @State private var result: String? = nil
    @State private var score = 0
    @State private var attempts = 0
    @State private var revealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Ear Training").font(.title2.bold())
                Spacer()
                Text("Score: \(score) / \(attempts)")
                    .monospacedDigit().foregroundStyle(.secondary)
            }

            Picker("Exercise", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: mode) { _, _ in newQuestion() }

            Text(instruction).foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button { replay() } label: { Label("Play", systemImage: "play.fill") }
                Button("New question") { newQuestion() }
                Button("Reveal") { revealed = true; result = "Answer: \(answer)" }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 8) {
                ForEach(choices, id: \.self) { choice in
                    Button {
                        check(choice)
                    } label: {
                        Text(choice).frame(maxWidth: .infinity).padding(.vertical, 4)
                    }
                    .tint(revealed && choice == answer ? .green : nil)
                }
            }

            if let result {
                Text(result)
                    .font(.headline)
                    .foregroundStyle(result.hasPrefix("Correct") ? .green : (result.hasPrefix("Answer") ? .secondary : .red))
            }
            Spacer()
        }
        .padding(22)
        .navigationTitle("Ear Training")
        .onAppear { if prompt.isEmpty { newQuestion() } }
    }

    private var instruction: String {
        switch mode {
        case .intervals: return "Two notes play in sequence. Name the interval between them."
        case .chordQuality: return "A chord plays. Identify its quality."
        case .cadence: return "A two-chord cadence plays in the working key. Name it."
        case .scaleDegree: return "The tonic plays, then a scale note. Name the scale degree."
        }
    }

    private func newQuestion() {
        revealed = false
        result = nil
        var rng = SystemRandomNumberGenerator()
        switch mode {
        case .intervals:
            let base = Int.random(in: 55...67, using: &rng)
            let semis = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12].randomElement(using: &rng)!
            prompt = [Note(midi: base), Note(midi: base + semis)]
            answer = Interval(semitones: semis).longName
            choices = Interval.all.dropFirst().map(\.longName)
        case .chordQuality:
            let qualities: [ChordQuality] = [.major, .minor, .diminished, .augmented, .dominant7, .major7, .minor7, .halfDiminished7]
            let q = qualities.randomElement(using: &rng)!
            let root = PitchClass.allCases.randomElement(using: &rng)!
            prompt = Chord(root: root, quality: q).notes(octave: 3)
            answer = q.rawValue
            choices = qualities.map(\.rawValue)
        case .cadence:
            let dc = state.key.diatonicChords()
            let options: [(String, [Int])] = [
                ("Authentic (V–I)", [5, 1]),
                ("Plagal (IV–I)", [4, 1]),
                ("Half (I–V)", [1, 5]),
                ("Deceptive (V–vi)", [5, 6]),
            ]
            let pick = options.randomElement(using: &rng)!
            prompt = []
            answer = pick.0
            choices = options.map(\.0)
            cadenceChords = pick.1.map { dc[$0 - 1].chord }
        case .scaleDegree:
            let scale = Scale(root: state.tonic, type: state.scaleType)
            let notes = scale.notes(fromOctave: 4)
            let idx = Int.random(in: 0..<notes.count, using: &rng)
            prompt = [Note(state.tonic, octave: 4), notes[idx]]
            let labels = state.scaleType.degreeLabels + ["8"]
            answer = idx < labels.count ? labels[idx] : "\(idx + 1)"
            choices = Array((state.scaleType.degreeLabels + ["8"]).prefix(notes.count))
        }
        replay()
    }

    @State private var cadenceChords: [Chord] = []

    private func replay() {
        AudioEngine.shared.stopAll()
        if mode == .cadence {
            for (i, chord) in cadenceChords.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.9) {
                    AudioEngine.shared.playChord(chord.notes(octave: 3), duration: 0.85)
                }
            }
        } else if mode == .chordQuality {
            AudioEngine.shared.playChord(prompt, duration: 1.4)
        } else {
            AudioEngine.shared.playSequence(prompt, noteDuration: 0.6)
        }
    }

    private func check(_ choice: String) {
        guard !revealed, result?.hasPrefix("Correct") != true else { return }
        attempts += 1
        if choice == answer {
            score += 1
            result = "Correct — \(answer)"
        } else {
            result = "Not quite. Try again or Reveal."
            attempts -= 0
        }
    }
}
