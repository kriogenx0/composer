import SwiftUI

// MARK: - Model

struct PolyVoice: Identifiable, Equatable {
    let id = UUID()
    var count: Int          // evenly spaced nodes around the ring
    var colorIndex: Int
    var pitch: Int          // MIDI note for the click
    var muted: Bool = false
    var accent: Bool = true  // emphasise node 0 (the downbeat)

    var color: Color { PolyrhythmPalette.colors[colorIndex % PolyrhythmPalette.colors.count] }
}

enum PolyrhythmPalette {
    static let colors: [Color] = [.orange, .cyan, .pink, .green, .purple]
    static let pitchOptions: [(name: String, midi: Int)] = [
        ("Sub", 48), ("Low", 60), ("Mid", 72), ("High", 84), ("Top", 96),
    ]
}

// MARK: - Clock / audio engine

/// Drives the rotating hand's phase and fires a click each time the hand
/// crosses one of a voice's nodes. Visuals read `phase(at:)`; audio is done
/// here on a fine-grained timer so it stays tight regardless of frame rate.
@MainActor
final class PolyrhythmEngine: ObservableObject {
    @Published private(set) var running = false
    @Published private(set) var cycleIndex = 0

    var voices: [PolyVoice] = []
    var cycleSeconds: Double = 2.0

    private(set) var startDate = Date()
    private var timer: DispatchSourceTimer?
    private var lastPhase = 0.0

    /// 0…1 position of the hand within the current rotation.
    func phase(at date: Date = Date()) -> Double {
        guard running else { return 0 }
        let t = date.timeIntervalSince(startDate) / cycleSeconds
        return t - floor(t)
    }

    func toggle() { running ? stop() : start() }

    func start() {
        guard !running else { return }
        running = true
        cycleIndex = 0
        startDate = Date()
        lastPhase = -0.0001
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now(), repeating: .milliseconds(6), leeway: .milliseconds(1))
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
    }

    func stop() {
        running = false
        timer?.cancel()
        timer = nil
        AudioEngine.shared.stopAll()
    }

    /// Keep the hand where it is when the tempo changes instead of jumping.
    func retune(to newCycleSeconds: Double) {
        guard running else { cycleSeconds = newCycleSeconds; return }
        let p = phase()
        cycleSeconds = newCycleSeconds
        startDate = Date().addingTimeInterval(-p * newCycleSeconds)
        lastPhase = p
    }

    private func tick() {
        let p = phase()
        let prev = lastPhase
        lastPhase = p
        let wrapped = p < prev
        if wrapped { cycleIndex += 1 }

        for voice in voices where !voice.muted && voice.count > 0 {
            for i in 0..<voice.count {
                let node = Double(i) / Double(voice.count)
                let crossed = wrapped
                    ? (node > prev || node <= p)
                    : (node > prev && node <= p)
                guard crossed else { continue }
                let accent = voice.accent && i == 0
                AudioEngine.shared.play(midi: voice.pitch,
                                        velocity: accent ? 120 : 88,
                                        duration: accent ? 0.18 : 0.11)
            }
        }
    }
}

// MARK: - View

struct PolyrhythmView: View {
    @StateObject private var engine = PolyrhythmEngine()

    @State private var voices: [PolyVoice] = [
        PolyVoice(count: 3, colorIndex: 0, pitch: 72),
        PolyVoice(count: 4, colorIndex: 1, pitch: 60),
    ]
    @State private var cycleSeconds: Double = 2.0

    private let hitWindowSeconds = 0.16

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            wheel
                .frame(minWidth: 360, minHeight: 360)
                .aspectRatio(1, contentMode: .fit)
                .layoutPriority(1)

            controls
                .frame(width: 320)
        }
        .padding(24)
        .navigationTitle("Polyrhythm")
        .onAppear { pushToEngine() }
        .onChange(of: voices) { _, _ in pushToEngine() }
        .onChange(of: cycleSeconds) { _, new in
            engine.retune(to: new)
            pushToEngine()
        }
        .onDisappear { engine.stop() }
    }

    private func pushToEngine() {
        engine.voices = voices
        if !engine.running { engine.cycleSeconds = cycleSeconds }
    }

    // MARK: Wheel

    private var wheel: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !engine.running)) { timeline in
            Canvas { ctx, size in
                draw(in: ctx, size: size, now: timeline.date)
            }
            .background(RoundedRectangle(cornerRadius: 16).fill(.black.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.quaternary))
        }
    }

    private func draw(in ctx: GraphicsContext, size: CGSize, now: Date) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let outer = min(size.width, size.height) / 2 - 34
        let inner = outer * 0.40
        let phase = engine.phase(at: now)

        func ringRadius(_ v: Int) -> CGFloat {
            guard voices.count > 1 else { return outer }
            let f = 1 - Double(v) / Double(voices.count - 1)
            return inner + (outer - inner) * f
        }
        func point(_ nodePhase: Double, _ radius: CGFloat) -> CGPoint {
            let a = -Double.pi / 2 + nodePhase * 2 * .pi
            return CGPoint(x: center.x + radius * CGFloat(cos(a)),
                           y: center.y + radius * CGFloat(sin(a)))
        }

        // Rings + nodes
        for (v, voice) in voices.enumerated() {
            let radius = ringRadius(v)
            let ringRect = CGRect(x: center.x - radius, y: center.y - radius,
                                  width: radius * 2, height: radius * 2)
            ctx.stroke(Path(ellipseIn: ringRect),
                       with: .color(voice.muted ? .gray.opacity(0.15) : voice.color.opacity(0.28)),
                       lineWidth: 1.5)

            guard voice.count > 0 else { continue }
            for i in 0..<voice.count {
                let nodePhase = Double(i) / Double(voice.count)
                var delta = phase - nodePhase
                if delta < 0 { delta += 1 }
                let windowPhase = hitWindowSeconds / cycleSeconds
                let hot = engine.running && delta < windowPhase ? 1 - delta / windowPhase : 0
                let p = point(nodePhase, radius)

                let base: CGFloat = (i == 0 && voice.accent) ? 7 : 5
                let r = base + CGFloat(hot) * 9
                if hot > 0.01 {
                    let glow = r + 10
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - glow, y: p.y - glow, width: glow * 2, height: glow * 2)),
                             with: .color(voice.color.opacity(0.25 * hot)))
                }
                let fillColor = voice.muted
                    ? Color.gray.opacity(0.3)
                    : voice.color.opacity(0.55 + 0.45 * hot)
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                         with: .color(fillColor))
            }

            // ring count label, just outside the 12 o'clock node
            let labelPoint = point(0, radius + 15)
            ctx.draw(Text("\(voice.count)").font(.caption2.bold())
                        .foregroundColor(voice.muted ? .secondary : voice.color),
                     at: labelPoint)
        }

        // Sweep trail
        if engine.running {
            let trail = Path { p in
                let steps = 24
                for s in 0...steps {
                    let tp = phase - 0.11 * Double(s) / Double(steps)
                    let pt = point(tp, outer)
                    s == 0 ? p.move(to: pt) : p.addLine(to: pt)
                }
            }
            ctx.stroke(trail, with: .color(.white.opacity(0.35)),
                       style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }

        // Hand
        let tip = point(phase, outer + 4)
        let backEnd = point(phase + 0.5, inner * 0.5)
        var hand = Path()
        hand.move(to: backEnd)
        hand.addLine(to: tip)
        ctx.stroke(hand, with: .color(.primary.opacity(0.85)),
                   style: StrokeStyle(lineWidth: 3, lineCap: .round))
        ctx.fill(Path(ellipseIn: CGRect(x: tip.x - 5, y: tip.y - 5, width: 10, height: 10)),
                 with: .color(.primary))

        // Hub + ratio
        ctx.fill(Path(ellipseIn: CGRect(x: center.x - 7, y: center.y - 7, width: 14, height: 14)),
                 with: .color(.primary))
        ctx.draw(Text(ratioText).font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary),
                 at: CGPoint(x: center.x, y: center.y + inner * 0.5))
    }

    // MARK: Controls

    private var controls: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Polyrhythm").font(.title2.bold())
                Text("Each ring is one pulse, divided into equal steps. The hand sweeps one full "
                     + "turn per cycle and strikes a ring whenever it passes a dot — so the rings "
                     + "line up only at the top.")
                    .font(.callout).foregroundStyle(.secondary)

                Button {
                    pushToEngine()
                    engine.toggle()
                } label: {
                    Label(engine.running ? "Stop" : "Play",
                          systemImage: engine.running ? "stop.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .keyboardShortcut(.space, modifiers: [])
                .controlSize(.large)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Tempo").font(.callout)
                        Spacer()
                        Text("\(Int((60.0 / cycleSeconds).rounded())) cycles/min")
                            .font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    // Faster tempo = shorter cycle; invert the slider so right = faster.
                    Slider(value: Binding(
                        get: { 5.0 - cycleSeconds },
                        set: { cycleSeconds = (5.0 - $0).clamped(0.6, 4.0) }
                    ), in: 1.0...4.4)
                }

                Divider()

                ForEach($voices) { $voice in
                    voiceRow($voice)
                }

                HStack {
                    Button {
                        guard voices.count < 5 else { return }
                        let used = Set(voices.map(\.colorIndex))
                        let nextColor = (0..<PolyrhythmPalette.colors.count).first { !used.contains($0) } ?? voices.count
                        voices.append(PolyVoice(count: [5, 7, 2, 6].first { c in !voices.contains { $0.count == c } } ?? 5,
                                                colorIndex: nextColor,
                                                pitch: 54))
                    } label: { Label("Add ring", systemImage: "plus.circle") }
                        .disabled(voices.count >= 5)

                    Spacer()

                    Menu("Presets") {
                        presetButton("2 : 3", [2, 3])
                        presetButton("3 : 4", [3, 4])
                        presetButton("3 : 5", [3, 5])
                        presetButton("4 : 5", [4, 5])
                        presetButton("5 : 7", [5, 7])
                        presetButton("2 : 3 : 4", [2, 3, 4])
                        presetButton("3 : 4 : 5", [3, 4, 5])
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 90)
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Implied tempos").font(.headline)
                    ForEach(voices) { v in
                        HStack {
                            Circle().fill(v.color).frame(width: 9, height: 9)
                            Text("\(v.count) per cycle")
                            Spacer()
                            Text("\(Int((Double(v.count) * 60.0 / cycleSeconds).rounded())) BPM")
                                .monospacedDigit().foregroundStyle(.secondary)
                        }
                        .font(.callout)
                    }
                    Text("A 3 : 4 polyrhythm is “3 in the time of 4”. Feel each ring as its own "
                         + "steady beat; the interference between them is the groove.")
                        .font(.caption).foregroundStyle(.secondary).padding(.top, 4)
                }
            }
            .padding(.trailing, 4)
        }
    }

    private func voiceRow(_ voice: Binding<PolyVoice>) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Circle().fill(voice.wrappedValue.color)
                    .frame(width: 12, height: 12)
                Stepper("\(voice.wrappedValue.count) steps",
                        value: voice.count, in: 2...12)
                    .fixedSize()
                Spacer()
                Button {
                    if voices.count > 1 { voices.removeAll { $0.id == voice.wrappedValue.id } }
                } label: { Image(systemName: "minus.circle") }
                    .buttonStyle(.borderless)
                    .disabled(voices.count <= 1)
            }
            HStack(spacing: 8) {
                Picker("", selection: voice.pitch) {
                    ForEach(PolyrhythmPalette.pitchOptions, id: \.midi) { opt in
                        Text(opt.name).tag(opt.midi)
                    }
                }
                .labelsHidden()
                .frame(width: 84)
                Toggle("Accent", isOn: voice.accent).toggleStyle(.checkbox)
                Toggle("Mute", isOn: voice.muted).toggleStyle(.checkbox)
                Spacer()
            }
            .font(.callout)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.4)))
    }

    private func presetButton(_ title: String, _ counts: [Int]) -> some View {
        Button(title) {
            voices = counts.enumerated().map { idx, c in
                PolyVoice(count: c, colorIndex: idx,
                          pitch: PolyrhythmPalette.pitchOptions[min(idx + 1, PolyrhythmPalette.pitchOptions.count - 1)].midi)
            }
        }
    }

    private var ratioText: String { voices.map { "\($0.count)" }.joined(separator: " : ") }
}

private extension Double {
    func clamped(_ lo: Double, _ hi: Double) -> Double { Swift.min(hi, Swift.max(lo, self)) }
}
