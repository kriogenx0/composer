import SwiftUI

struct MetronomeView: View {
    @StateObject private var metro = Metronome()
    @State private var tapTimes: [Date] = []

    var body: some View {
        VStack(spacing: 26) {
            Text("Metronome").font(.title2.bold())

            Text("\(Int(metro.tempo))")
                .font(.system(size: 76, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text("BPM").foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ForEach(Array(0..<max(1, metro.timeSignature.numerator)), id: \.self) { beat in
                    Circle()
                        .fill(beat == metro.currentBeat && metro.isRunning
                              ? (beat == 0 ? Color.orange : Color.accentColor)
                              : Color.secondary.opacity(0.25))
                        .frame(width: beat == 0 ? 22 : 16, height: beat == 0 ? 22 : 16)
                }
            }
            .frame(height: 28)

            Slider(value: Binding(get: { metro.tempo }, set: { metro.updateTempo($0) }),
                   in: 40...240, step: 1)
                .frame(width: 360)

            HStack(spacing: 12) {
                Button("−5") { metro.updateTempo(metro.tempo - 5) }
                Button {
                    metro.toggle()
                } label: {
                    Label(metro.isRunning ? "Stop" : "Start",
                          systemImage: metro.isRunning ? "stop.fill" : "play.fill")
                        .frame(width: 90)
                }
                .keyboardShortcut(.space, modifiers: [])
                Button("+5") { metro.updateTempo(metro.tempo + 5) }
                Button("Tap tempo") { tap() }
            }

            HStack(spacing: 20) {
                Picker("Time signature", selection: $metro.timeSignature) {
                    ForEach(TimeSignature.common) { Text($0.display).tag($0) }
                }.frame(width: 170)
                Picker("Subdivision", selection: $metro.subdivision) {
                    Text("Quarter").tag(1)
                    Text("Eighth").tag(2)
                    Text("Triplet").tag(3)
                    Text("Sixteenth").tag(4)
                }.frame(width: 170)
                Toggle("Accent downbeat", isOn: $metro.accentDownbeat)
                    .toggleStyle(.checkbox)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .navigationTitle("Metronome")
        .onDisappear { metro.stop() }
    }

    private func tap() {
        let now = Date()
        tapTimes.append(now)
        tapTimes = tapTimes.filter { now.timeIntervalSince($0) < 3 }
        guard tapTimes.count >= 2 else { return }
        let intervals = zip(tapTimes.dropFirst(), tapTimes).map { $0.timeIntervalSince($1) }
        let avg = intervals.reduce(0, +) / Double(intervals.count)
        if avg > 0 { metro.updateTempo(60.0 / avg) }
    }
}
