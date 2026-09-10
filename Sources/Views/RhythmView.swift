import SwiftUI

struct RhythmView: View {
    @EnvironmentObject var state: AppState
    @State private var isPreviewing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Rhythm & Syncopation").font(.title2.bold())
                Text("Build a one-bar rhythmic figure. It shapes both playback and the exported MIDI.")
                    .foregroundStyle(.secondary)

                meterControls
                syncopationControls
                grid
                presets
                explanation
            }
            .padding(22)
        }
        .navigationTitle("Rhythm & Syncopation")
    }

    private var meterControls: some View {
        HStack(spacing: 18) {
            Picker("Time signature", selection: $state.timeSignature) {
                ForEach(TimeSignature.common) { Text($0.display).tag($0) }
            }
            .frame(maxWidth: 180)
            .onChange(of: state.timeSignature) { _, _ in
                state.rebuildRhythmGrid(); state.captureRhythmBase()
            }

            Picker("Subdivision", selection: $state.subdivision) {
                ForEach(Subdivision.allCases) { Text($0.rawValue).tag($0) }
            }
            .frame(maxWidth: 200)
            .onChange(of: state.subdivision) { _, _ in
                state.rebuildRhythmGrid(); state.captureRhythmBase()
            }

            HStack {
                Text("Swing")
                Slider(value: Binding(
                    get: { state.rhythmPattern.swing },
                    set: { state.rhythmPattern.swing = $0; state.captureRhythmBase() }
                ), in: 0...0.66).frame(width: 140)
                Text("\(Int(state.rhythmPattern.swing * 100))%").monospacedDigit()
            }
        }
    }

    private var syncopationControls: some View {
        HStack(spacing: 14) {
            Text("Syncopation")
            Slider(value: $state.syncopation, in: 0...1, step: 0.05)
                .frame(width: 260)
                .onChange(of: state.syncopation) { _, _ in state.applySyncopation() }
            Text("\(Int(state.syncopation * 100))%").monospacedDigit().frame(width: 44)
            Button("Anchor current pattern") { state.captureRhythmBase() }
                .help("Use the current grid as the basis the syncopation slider works from.")
            Button {
                isPreviewing.toggle()
                if isPreviewing { previewPattern() }
            } label: {
                Label("Preview", systemImage: "speaker.wave.2.fill")
            }
        }
    }

    private var grid: some View {
        StepGridView(pattern: $state.rhythmPattern)
            .frame(height: 108)
            .onChange(of: state.rhythmPattern.steps) { _, _ in }
    }

    private var presets: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preset grooves").font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(RhythmLibrary.presets(for: state.timeSignature)) { preset in
                    Button {
                        state.applyPreset(preset)
                        state.syncopation = 0
                    } label: {
                        Text(preset.name).frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private var explanation: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What is syncopation?").font(.headline)
            Text("""
            Syncopation places emphasis where the ear expects silence or weakness — on off-beats, \
            or by tying a note across a strong beat so the accent lands early (an anticipation) or \
            late (a suspension of the pulse). The slider takes plain on-beat hits and pushes a share \
            of them onto the neighbouring off-beat, adding ties so the groove still connects. \
            Swing instead delays every other subdivision, turning straight eighths into a long–short \
            lilt without moving the beats themselves.
            """)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.4)))
    }

    private func previewPattern() {
        let notes = [Note(.c, octave: 4), Note(.e, octave: 4), Note(.g, octave: 4)]
        let bpm = state.playbackTempo
        let barQuarters = state.rhythmPattern.timeSignature.quarterBeatsPerBar
        let secPerQuarter = 60.0 / bpm
        for onset in state.rhythmPattern.onsets() {
            let delay = onset.time * secPerQuarter
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                for n in notes {
                    AudioEngine.shared.play(midi: n.midi, velocity: onset.accent ? 100 : 74, duration: 0.25)
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + barQuarters * secPerQuarter + 0.1) {
            isPreviewing = false
        }
    }
}
