import Foundation

struct MIDIExportOptions {
    var tempoBPM: Double = 100
    var beatsPerChord: Double = 4         // in quarter notes
    var includeChords = true
    var includeBass = true
    var includeArpeggio = false
    var applyRhythm = true
    var humanize = true
    var chordOctave = 3
    var bassOctave = 2
    var arpeggioOctave = 4
}

enum MIDIExporter {

    static func export(progression: Progression,
                       rhythm: RhythmPattern?,
                       options: MIDIExportOptions) -> Data {
        var file = MIDIFile(ppq: 480)
        let ppq = Double(file.ppq)
        let chordTicks = Int(options.beatsPerChord * ppq)

        var chordTrack = MIDIFile.MIDITrack(name: "Chords")
        chordTrack.addProgramChange(channel: 0, program: 0)      // acoustic grand
        var bassTrack = MIDIFile.MIDITrack(name: "Bass")
        bassTrack.addProgramChange(channel: 1, program: 33)      // fingered bass
        var arpTrack = MIDIFile.MIDITrack(name: "Arpeggio")
        arpTrack.addProgramChange(channel: 2, program: 4)        // electric piano

        var seed = SplitMix64(seed: 0xC0FFEE)

        for (index, pc) in progression.chords.enumerated() {
            let barStart = index * chordTicks
            let notes = pc.chord.notes(octave: options.chordOctave)
            let rootNote = Note(pc.chord.bassPitchClass, octave: options.bassOctave)

            let hits = rhythmHits(rhythm: rhythm, apply: options.applyRhythm,
                                  spanTicks: chordTicks, ppq: ppq)

            for hit in hits {
                let start = barStart + hit.startTick
                let dur = hit.durationTick
                let baseVel = hit.accent ? 104 : 84
                if options.includeChords {
                    for n in notes {
                        let v = humanized(baseVel, options.humanize, &seed)
                        chordTrack.addNote(channel: 0, note: UInt8(clampMIDI(n.midi)),
                                           velocity: UInt8(v), start: jitter(start, options.humanize, &seed),
                                           duration: dur)
                    }
                }
                if options.includeBass {
                    let v = humanized(baseVel + 6, options.humanize, &seed)
                    bassTrack.addNote(channel: 1, note: UInt8(clampMIDI(rootNote.midi)),
                                      velocity: UInt8(v), start: jitter(start, options.humanize, &seed),
                                      duration: dur)
                }
            }

            if options.includeArpeggio {
                let arpNotes = pc.chord.notes(octave: options.arpeggioOctave)
                let stepDur = chordTicks / 8
                for i in 0..<8 {
                    let n = arpNotes[i % arpNotes.count].midi + (i / arpNotes.count) * 12
                    let v = humanized(74, options.humanize, &seed)
                    arpTrack.addNote(channel: 2, note: UInt8(clampMIDI(n)), velocity: UInt8(v),
                                     start: jitter(barStart + i * stepDur, options.humanize, &seed),
                                     duration: stepDur - 8)
                }
            }
        }

        if options.includeChords { file.tracks.append(chordTrack) }
        if options.includeBass { file.tracks.append(bassTrack) }
        if options.includeArpeggio { file.tracks.append(arpTrack) }

        return file.encoded(tempoBPM: options.tempoBPM,
                            timeSignature: rhythm?.timeSignature ?? TimeSignature(numerator: 4, denominator: 4))
    }

    private struct Hit { var startTick: Int; var durationTick: Int; var accent: Bool }

    private static func rhythmHits(rhythm: RhythmPattern?, apply: Bool,
                                   spanTicks: Int, ppq: Double) -> [Hit] {
        guard apply, let rhythm, !rhythm.onsets().isEmpty else {
            return [Hit(startTick: 0, durationTick: spanTicks - 4, accent: true)]
        }
        let onsets = rhythm.onsets()
        let barQuarters = rhythm.timeSignature.quarterBeatsPerBar
        var hits: [Hit] = []
        for (i, onset) in onsets.enumerated() {
            let startTick = Int(onset.time / barQuarters * Double(spanTicks))
            let endQuarter: Double
            if i + 1 < onsets.count {
                endQuarter = onsets[i + 1].time
            } else {
                endQuarter = barQuarters
            }
            let stepQuarter = 1.0 / Double(rhythm.subdivision.stepsPerQuarter)
            let tiedEnd = min(endQuarter, onset.time + Double(onset.durationSteps) * stepQuarter)
            let endTick = Int(max(onset.time + stepQuarter, tiedEnd) / barQuarters * Double(spanTicks))
            hits.append(Hit(startTick: startTick,
                            durationTick: max(8, endTick - startTick - 4),
                            accent: onset.accent))
        }
        return hits
    }

    private static func clampMIDI(_ v: Int) -> Int { max(0, min(127, v)) }

    private static func humanized(_ base: Int, _ on: Bool, _ seed: inout SplitMix64) -> Int {
        guard on else { return clampMIDI(base) }
        return clampMIDI(base + Int.random(in: -7...7, using: &seed))
    }

    private static func jitter(_ tick: Int, _ on: Bool, _ seed: inout SplitMix64) -> Int {
        guard on else { return max(0, tick) }
        return max(0, tick + Int.random(in: -6...6, using: &seed))
    }
}
