import Foundation
import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    // Key context shared across the app
    @Published var tonic: PitchClass = .c
    @Published var scaleType: ScaleType = .major
    var key: Key { Key(tonic: tonic, scale: scaleType) }

    // Progression
    @Published var options = ProgressionOptions()
    @Published var progression: Progression?
    @Published var playingChordIndex: Int? = nil
    @Published var isPlaying = false
    @Published var arpeggiatePlayback = false
    @Published var playbackTempo: Double = 100
    @Published var beatsPerChord: Double = 4
    private var seedCounter: UInt64 = UInt64(Date().timeIntervalSince1970)

    // Rhythm
    @Published var timeSignature = TimeSignature(numerator: 4, denominator: 4)
    @Published var subdivision: Subdivision = .sixteenth
    @Published var rhythmPattern: RhythmPattern
    @Published var syncopation: Double = 0
    @Published var useRhythmInPlayback = true

    // MIDI export
    @Published var midiOptions = MIDIExportOptions()

    init() {
        let ts = TimeSignature(numerator: 4, denominator: 4)
        rhythmPattern = RhythmLibrary.presets(for: ts).first
            ?? RhythmPattern.empty(ts, .sixteenth)
        regenerate()
    }

    // MARK: Progression actions

    func nextSeed() -> SplitMix64 {
        seedCounter = seedCounter &* 6364136223846793005 &+ 1442695040888963407
        return SplitMix64(seed: seedCounter)
    }

    func regenerate() {
        var seed = nextSeed()
        let locked = progression?.chords.filter(\.locked) ?? []
        var new = ProgressionGenerator.generate(key: key, options: options, seed: &seed)
        // Restore locked slots by position.
        if let old = progression {
            for (i, chord) in old.chords.enumerated() where chord.locked && i < new.chords.count {
                new.chords[i] = chord
            }
        }
        _ = locked
        progression = new
    }

    func rerollChord(at index: Int) {
        guard var prog = progression, index < prog.chords.count, !prog.chords[index].locked else { return }
        var seed = nextSeed()
        let replacement = ProgressionGenerator.reroll(prog, at: index, options: options, seed: &seed)
        var slot = replacement
        slot.locked = false
        prog.chords[index] = slot
        progression = prog
    }

    func toggleLock(at index: Int) {
        guard var prog = progression, index < prog.chords.count else { return }
        prog.chords[index].locked.toggle()
        progression = prog
    }

    func setLength(_ n: Int) {
        options.length = max(2, min(16, n))
        regenerate()
    }

    // MARK: Rhythm actions

    func applyPreset(_ preset: RhythmPattern) {
        rhythmPattern = preset
        timeSignature = preset.timeSignature
        subdivision = preset.subdivision
        applySyncopation()
    }

    func rebuildRhythmGrid() {
        let count = RhythmPattern.stepCount(ts: timeSignature, sub: subdivision)
        if rhythmPattern.steps.count != count {
            rhythmPattern = RhythmPattern.empty(timeSignature, subdivision)
        }
        rhythmPattern.timeSignature = timeSignature
        rhythmPattern.subdivision = subdivision
    }

    private var baseRhythm: RhythmPattern?
    func applySyncopation() {
        if baseRhythm == nil || baseRhythm?.timeSignature != rhythmPattern.timeSignature {
            baseRhythm = rhythmPattern
        }
        guard let base = baseRhythm else { return }
        if syncopation <= 0 {
            rhythmPattern = base
            return
        }
        var seed = SplitMix64(seed: UInt64(syncopation * 1000) &+ 7)
        rhythmPattern = RhythmLibrary.syncopate(base, amount: syncopation, seed: &seed)
    }

    func captureRhythmBase() { baseRhythm = rhythmPattern }

    // MARK: Playback

    func playProgression() {
        guard let progression else { return }
        isPlaying = true
        AudioEngine.shared.playProgression(
            progression,
            rhythm: useRhythmInPlayback ? rhythmPattern : nil,
            tempoBPM: playbackTempo,
            beatsPerChord: beatsPerChord,
            arpeggiate: arpeggiatePlayback,
            onChordStart: { [weak self] idx in self?.playingChordIndex = idx },
            onFinish: { [weak self] in
                self?.isPlaying = false
                self?.playingChordIndex = nil
            }
        )
    }

    func stopPlayback() {
        AudioEngine.shared.stopAll()
        isPlaying = false
        playingChordIndex = nil
    }

    // MARK: MIDI

    func makeMIDIData() -> Data {
        var opts = midiOptions
        opts.tempoBPM = playbackTempo
        opts.beatsPerChord = beatsPerChord
        guard let progression else { return Data() }
        return MIDIExporter.export(progression: progression,
                                   rhythm: opts.applyRhythm ? rhythmPattern : nil,
                                   options: opts)
    }

    var suggestedFileName: String {
        let k = key.shortName.replacingOccurrences(of: " ", with: "-")
        return "Composer-\(k)-\(options.length)chords.mid"
    }
}
