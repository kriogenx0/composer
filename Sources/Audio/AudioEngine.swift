import AVFoundation
import Foundation

/// Wraps AVAudioEngine + a General-MIDI sampler for simple playback of notes,
/// chords, scales and sequenced progressions.
final class AudioEngine {
    static let shared = AudioEngine()

    private let engine = AVAudioEngine()
    private let melodic = AVAudioUnitSampler()
    private var started = false
    private var scheduledWork: [DispatchWorkItem] = []

    private init() {
        engine.attach(melodic)
        engine.connect(melodic, to: engine.mainMixerNode, format: nil)
        loadSoundbank()
    }

    private func loadSoundbank() {
        let candidates = [
            "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls",
            "/System/Library/Frameworks/DLSMusicDevice.framework/Resources/gs_instruments.dls",
        ]
        for path in candidates where FileManager.default.fileExists(atPath: path) {
            do {
                try melodic.loadSoundBankInstrument(
                    at: URL(fileURLWithPath: path),
                    program: 0, bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                    bankLSB: UInt8(kAUSampler_DefaultBankLSB))
                return
            } catch { continue }
        }
        // Falls back to the sampler's built-in sine tone if no bank is available.
    }

    func start() {
        guard !started else { return }
        do {
            try engine.start()
            started = true
        } catch {
            NSLog("AudioEngine start failed: \(error.localizedDescription)")
        }
    }

    func setInstrument(program: UInt8) {
        try? melodic.loadSoundBankInstrument(
            at: URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls"),
            program: program, bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
            bankLSB: UInt8(kAUSampler_DefaultBankLSB))
    }

    // MARK: One-shots

    func noteOn(_ midi: Int, velocity: UInt8 = 90) {
        start()
        melodic.startNote(UInt8(max(0, min(127, midi))), withVelocity: velocity, onChannel: 0)
    }

    func noteOff(_ midi: Int) {
        melodic.stopNote(UInt8(max(0, min(127, midi))), onChannel: 0)
    }

    func play(midi: Int, velocity: UInt8 = 90, duration: TimeInterval = 0.6) {
        start()
        let n = UInt8(max(0, min(127, midi)))
        melodic.startNote(n, withVelocity: velocity, onChannel: 0)
        let work = DispatchWorkItem { [weak self] in self?.melodic.stopNote(n, onChannel: 0) }
        scheduledWork.append(work)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    func playChord(_ notes: [Note], velocity: UInt8 = 84, duration: TimeInterval = 1.2) {
        for n in notes { play(midi: n.midi, velocity: velocity, duration: duration) }
    }

    func playSequence(_ notes: [Note], noteDuration: TimeInterval = 0.4, gap: TimeInterval = 0.0) {
        start()
        stopAll()
        for (i, n) in notes.enumerated() {
            let when = Double(i) * (noteDuration + gap)
            let work = DispatchWorkItem { [weak self] in
                self?.play(midi: n.midi, duration: noteDuration)
            }
            scheduledWork.append(work)
            DispatchQueue.main.asyncAfter(deadline: .now() + when, execute: work)
        }
    }

    /// Play a progression. Returns the total duration so callers can drive a playhead.
    @discardableResult
    func playProgression(_ progression: Progression,
                         rhythm: RhythmPattern?,
                         tempoBPM: Double,
                         beatsPerChord: Double,
                         arpeggiate: Bool,
                         onChordStart: ((Int) -> Void)? = nil,
                         onFinish: (() -> Void)? = nil) -> TimeInterval {
        start()
        stopAll()
        let secPerQuarter = 60.0 / max(1, tempoBPM)
        let chordSeconds = beatsPerChord * secPerQuarter
        var cursor: TimeInterval = 0

        for (index, pc) in progression.chords.enumerated() {
            let chordStart = cursor
            let notes = pc.chord.notes(octave: 3)

            let startWork = DispatchWorkItem { onChordStart?(index) }
            scheduledWork.append(startWork)
            DispatchQueue.main.asyncAfter(deadline: .now() + chordStart, execute: startWork)

            if arpeggiate {
                let count = 8
                let stepDur = chordSeconds / Double(count)
                for i in 0..<count {
                    let n = notes[i % notes.count].midi + (i / notes.count) * 12
                    schedule(at: chordStart + Double(i) * stepDur) { [weak self] in
                        self?.play(midi: n, velocity: 80, duration: stepDur * 0.9)
                    }
                }
            } else if let rhythm, !rhythm.onsets().isEmpty {
                let barQuarters = rhythm.timeSignature.quarterBeatsPerBar
                let onsets = rhythm.onsets()
                for (i, onset) in onsets.enumerated() {
                    let startFrac = onset.time / barQuarters
                    let nextTime = i + 1 < onsets.count ? onsets[i + 1].time : barQuarters
                    let durSec = max(0.12, (nextTime - onset.time) / barQuarters * chordSeconds * 0.95)
                    let vel: UInt8 = onset.accent ? 100 : 78
                    schedule(at: chordStart + startFrac * chordSeconds) { [weak self] in
                        for n in notes { self?.play(midi: n.midi, velocity: vel, duration: durSec) }
                    }
                }
            } else {
                schedule(at: chordStart) { [weak self] in
                    for n in notes { self?.play(midi: n.midi, velocity: 84, duration: chordSeconds * 0.95) }
                }
            }
            cursor += chordSeconds
        }

        let finishWork = DispatchWorkItem { onFinish?() }
        scheduledWork.append(finishWork)
        DispatchQueue.main.asyncAfter(deadline: .now() + cursor, execute: finishWork)
        return cursor
    }

    private func schedule(at delay: TimeInterval, _ block: @escaping () -> Void) {
        let work = DispatchWorkItem(block: block)
        scheduledWork.append(work)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func stopAll() {
        scheduledWork.forEach { $0.cancel() }
        scheduledWork.removeAll()
        for n in 0...127 { melodic.stopNote(UInt8(n), onChannel: 0) }
    }
}
