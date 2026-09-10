import Foundation

struct TimeSignature: Hashable, Identifiable, Codable {
    var numerator: Int
    var denominator: Int   // 2, 4, 8, 16
    var id: String { "\(numerator)/\(denominator)" }
    var display: String { "\(numerator)/\(denominator)" }

    /// Beats per bar in quarter-note units.
    var quarterBeatsPerBar: Double { Double(numerator) * 4.0 / Double(denominator) }

    var isCompound: Bool { denominator == 8 && numerator % 3 == 0 && numerator > 3 }

    static let common: [TimeSignature] = [
        .init(numerator: 4, denominator: 4),
        .init(numerator: 3, denominator: 4),
        .init(numerator: 2, denominator: 4),
        .init(numerator: 6, denominator: 8),
        .init(numerator: 9, denominator: 8),
        .init(numerator: 12, denominator: 8),
        .init(numerator: 5, denominator: 4),
        .init(numerator: 7, denominator: 8),
    ]
}

enum Subdivision: String, CaseIterable, Identifiable, Codable {
    case quarter = "Quarter"
    case eighth = "Eighth"
    case sixteenth = "Sixteenth"
    case eighthTriplet = "Eighth triplet"
    var id: String { rawValue }

    /// Steps per quarter note.
    var stepsPerQuarter: Int {
        switch self {
        case .quarter: return 1
        case .eighth: return 2
        case .sixteenth: return 4
        case .eighthTriplet: return 3
        }
    }
}

/// One cell of a rhythm grid.
struct RhythmStep: Hashable, Codable {
    var active: Bool
    var accent: Bool = false
    var tie: Bool = false     // sustain into the next step
}

struct RhythmPattern: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var timeSignature: TimeSignature
    var subdivision: Subdivision
    var steps: [RhythmStep]
    var swing: Double = 0        // 0…0.66 (0 = straight, 0.66 = hard triplet swing)

    var stepCount: Int { steps.count }
    var stepsPerBeat: Int { subdivision.stepsPerQuarter }

    /// Onset times (in quarter-note units) and whether each is accented.
    func onsets() -> [(time: Double, accent: Bool, durationSteps: Int)] {
        let stepDurQuarter = 1.0 / Double(subdivision.stepsPerQuarter)
        var result: [(Double, Bool, Int)] = []
        var i = 0
        while i < steps.count {
            guard steps[i].active else { i += 1; continue }
            var dur = 1
            var j = i + 1
            while j < steps.count, steps[j].tie, !steps[j].active {
                dur += 1; j += 1
            }
            var t = Double(i) * stepDurQuarter
            // Apply swing to odd (off-beat) steps.
            if swing > 0, subdivision == .eighth || subdivision == .sixteenth {
                let pairIndex = i % 2
                if pairIndex == 1 { t += stepDurQuarter * swing }
            }
            result.append((t, steps[i].accent, dur))
            i += 1
        }
        return result
    }

    static func empty(_ ts: TimeSignature, _ sub: Subdivision) -> RhythmPattern {
        let count = stepCount(ts: ts, sub: sub)
        return RhythmPattern(name: "Custom", timeSignature: ts, subdivision: sub,
                             steps: Array(repeating: RhythmStep(active: false), count: count))
    }

    static func stepCount(ts: TimeSignature, sub: Subdivision) -> Int {
        Int((ts.quarterBeatsPerBar * Double(sub.stepsPerQuarter)).rounded())
    }
}

enum RhythmLibrary {
    /// Preset patterns given as active-step index lists over a 4/4 sixteenth grid (16 steps),
    /// unless another grid is noted. Accented steps are listed separately.
    static func presets(for ts: TimeSignature) -> [RhythmPattern] {
        if ts.denominator == 8, ts.numerator % 3 == 0 {
            return compoundPresets(ts)
        }
        let sub = Subdivision.sixteenth
        let n = RhythmPattern.stepCount(ts: ts, sub: sub)
        func make(_ name: String, _ active: [Int], accents: [Int] = [], ties: [Int] = [], swing: Double = 0) -> RhythmPattern {
            var steps = Array(repeating: RhythmStep(active: false), count: n)
            for i in active where i < n { steps[i].active = true }
            for i in accents where i < n { steps[i].accent = true }
            for i in ties where i < n { steps[i].tie = true }
            return RhythmPattern(name: name, timeSignature: ts, subdivision: sub, steps: steps, swing: swing)
        }
        guard ts.numerator == 4, ts.denominator == 4 else {
            // Generic: quarter-note pulse for odd/other meters.
            let beats = stride(from: 0, to: n, by: sub.stepsPerQuarter).map { $0 }
            return [make("Straight pulse", beats, accents: [0])]
        }
        return [
            make("Straight quarters", [0, 4, 8, 12], accents: [0, 8]),
            make("Straight eighths", [0, 2, 4, 6, 8, 10, 12, 14], accents: [0, 8]),
            make("Sixteenths", Array(0..<16), accents: [0, 4, 8, 12]),
            make("Backbeat", [0, 4, 8, 12], accents: [4, 12]),
            make("Four on the floor", [0, 4, 8, 12], accents: [0, 4, 8, 12]),
            make("Tresillo (3+3+2)", [0, 3, 6], accents: [0]),
            make("Son clave (3-2)", [0, 3, 6, 10, 12], accents: [0, 6]),
            make("Rumba clave (3-2)", [0, 3, 7, 10, 12], accents: [0, 7]),
            make("Bossa nova", [0, 3, 6, 10, 13], accents: [0, 10]),
            make("Charleston", [0, 6], accents: [0, 6]),
            make("Dembow", [0, 3, 4, 6, 8, 11, 12, 14], accents: [0, 4, 8, 12]),
            make("Habanera", [0, 3, 4, 8, 12], accents: [0]),
            make("Syncopated push", [0, 3, 6, 8, 11, 14], accents: [3, 11], ties: [4, 12]),
            make("Swing eighths", [0, 2, 4, 6, 8, 10, 12, 14], accents: [0, 8], swing: 0.6),
            make("Offbeat skank", [2, 6, 10, 14], accents: [2, 10]),
        ]
    }

    private static func compoundPresets(_ ts: TimeSignature) -> [RhythmPattern] {
        let sub = Subdivision.eighth
        let n = RhythmPattern.stepCount(ts: ts, sub: sub)
        func make(_ name: String, _ active: [Int], accents: [Int] = []) -> RhythmPattern {
            var steps = Array(repeating: RhythmStep(active: false), count: n)
            for i in active where i < n { steps[i].active = true }
            for i in accents where i < n { steps[i].accent = true }
            return RhythmPattern(name: name, timeSignature: ts, subdivision: sub, steps: steps)
        }
        let dotted = stride(from: 0, to: n, by: 3).map { $0 }
        return [
            make("Compound pulse", dotted, accents: [0]),
            make("All eighths", Array(0..<n), accents: dotted),
            make("6/8 tresillo feel", [0, 2, 3, 5], accents: [0, 3]),
        ]
    }

    /// Push active onsets off the beat by up to `amount` (0…1): moves some downbeat
    /// hits to the following off-beat step and adds ties, producing syncopation.
    static func syncopate(_ pattern: RhythmPattern, amount: Double, seed: inout SplitMix64) -> RhythmPattern {
        guard amount > 0 else { return pattern }
        var steps = pattern.steps
        let perBeat = pattern.stepsPerBeat
        guard perBeat >= 2 else { return pattern }
        for beat in stride(from: 0, to: steps.count, by: perBeat) {
            guard beat + 1 < steps.count else { continue }
            let roll = Double.random(in: 0...1, using: &seed)
            if steps[beat].active, !steps[beat].accent, roll < amount {
                // Anticipate: move this hit earlier (tie from previous offbeat) …
                if beat - 1 >= 0, !steps[beat - 1].active {
                    steps[beat - 1].active = true
                    steps[beat - 1].accent = steps[beat].accent
                    steps[beat].active = false
                    steps[beat].tie = true
                } else if !steps[beat + 1].active {
                    // … or delay it to the off-beat.
                    steps[beat + 1].active = true
                    steps[beat + 1].accent = steps[beat].accent
                    steps[beat].active = false
                }
            }
        }
        var result = pattern
        result.name = pattern.name + " (syncopated)"
        result.steps = steps
        return result
    }
}
