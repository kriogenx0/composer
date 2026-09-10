import AVFoundation
import Foundation
import Combine

@MainActor
final class Metronome: ObservableObject {
    @Published var isRunning = false
    @Published var tempo: Double = 100
    @Published var timeSignature = TimeSignature(numerator: 4, denominator: 4)
    @Published var accentDownbeat = true
    @Published var subdivision: Int = 1        // clicks per beat
    @Published var currentBeat = 0

    private let engine = AVAudioEngine()
    private let sampler = AVAudioUnitSampler()
    private var timer: DispatchSourceTimer?
    private var tick = 0

    init() {
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)
        // GM program 115 = Woodblock; falls back to sine if no bank.
        try? sampler.loadSoundBankInstrument(
            at: URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls"),
            program: 115, bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
            bankLSB: UInt8(kAUSampler_DefaultBankLSB))
        try? engine.start()
    }

    func toggle() { isRunning ? stop() : start() }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        tick = 0
        currentBeat = 0
        scheduleTimer()
    }

    func stop() {
        isRunning = false
        timer?.cancel()
        timer = nil
    }

    func updateTempo(_ bpm: Double) {
        tempo = max(20, min(300, bpm))
        if isRunning { scheduleTimer() }
    }

    private func scheduleTimer() {
        timer?.cancel()
        let interval = 60.0 / tempo / Double(max(1, subdivision))
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now(), repeating: interval)
        t.setEventHandler { [weak self] in self?.fire() }
        t.resume()
        timer = t
    }

    private func fire() {
        let stepsPerBar = timeSignature.numerator * max(1, subdivision)
        let isBeat = tick % max(1, subdivision) == 0
        let isDownbeat = tick % stepsPerBar == 0
        let note: UInt8 = isDownbeat && accentDownbeat ? 84 : (isBeat ? 76 : 69)
        let vel: UInt8 = isDownbeat ? 110 : (isBeat ? 90 : 64)
        sampler.startNote(note, withVelocity: vel, onChannel: 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.sampler.stopNote(note, onChannel: 0)
        }
        if isBeat {
            currentBeat = (tick / max(1, subdivision)) % timeSignature.numerator
        }
        tick += 1
    }
}
