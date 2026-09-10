import Foundation

/// One slot in a progression. Keeps the diatonic context so it can be re-rolled.
struct ProgressionChord: Identifiable, Hashable {
    let id = UUID()
    var degree: Int
    var chord: Chord
    var roman: String
    var function: HarmonicFunction
    var locked: Bool = false
    var borrowed: Bool = false
    var secondaryOf: Int? = nil   // e.g. V/ii
}

struct Progression: Identifiable, Hashable {
    let id = UUID()
    var key: Key
    var chords: [ProgressionChord]

    var romanText: String { chords.map(\.roman).joined(separator: "  –  ") }
    func symbolText() -> String { chords.map { $0.chord.symbol(in: key) }.joined(separator: "  –  ") }
}

enum GenerationStyle: String, CaseIterable, Identifiable {
    case functional = "Functional (weighted)"
    case commonProgressions = "Common progressions"
    case randomDiatonic = "Random diatonic"
    case pop = "Pop / 4-chord loops"
    case jazz = "Jazz (ii–V–I chains)"
    var id: String { rawValue }
}

struct ProgressionOptions {
    var length: Int = 4
    var style: GenerationStyle = .functional
    var useSevenths: Bool = false
    var allowInversions: Bool = false
    var allowBorrowed: Bool = false
    var allowSecondaryDominants: Bool = false
    var startOnTonic: Bool = true
    var endWithCadence: Bool = true
}

enum ProgressionGenerator {

    // Weighted transitions between scale degrees (1-indexed) for major-mode functional harmony.
    private static let transitions: [Int: [(Int, Double)]] = [
        1: [(2, 0.20), (3, 0.10), (4, 0.28), (5, 0.24), (6, 0.18)],
        2: [(5, 0.55), (7, 0.15), (4, 0.15), (3, 0.15)],
        3: [(6, 0.40), (4, 0.30), (2, 0.15), (1, 0.15)],
        4: [(5, 0.45), (1, 0.20), (2, 0.15), (6, 0.10), (3, 0.10)],
        5: [(1, 0.55), (6, 0.25), (4, 0.12), (3, 0.08)],
        6: [(4, 0.30), (2, 0.30), (5, 0.20), (3, 0.10), (1, 0.10)],
        7: [(1, 0.75), (6, 0.15), (3, 0.10)],
    ]

    static let namedProgressions: [(name: String, degrees: [Int])] = [
        ("I–V–vi–IV (axis)", [1, 5, 6, 4]),
        ("I–IV–V–I", [1, 4, 5, 1]),
        ("ii–V–I", [2, 5, 1]),
        ("I–vi–IV–V (50s)", [1, 6, 4, 5]),
        ("vi–IV–I–V", [6, 4, 1, 5]),
        ("I–V–vi–iii–IV–I–IV–V (Pachelbel)", [1, 5, 6, 3, 4, 1, 4, 5]),
        ("12-bar blues", [1, 1, 1, 1, 4, 4, 1, 1, 5, 4, 1, 5]),
        ("I–IV–vi–V", [1, 4, 6, 5]),
        ("Andalusian i–VII–VI–V", [1, 7, 6, 5]),
        ("I–iii–IV–iv", [1, 3, 4, 4]),
    ]

    static func generate(key: Key, options: ProgressionOptions, seed: inout SplitMix64) -> Progression {
        let diatonic = key.diatonicChords(sevenths: options.useSevenths)
        guard diatonic.count == 7 else {
            return Progression(key: key, chords: [])
        }

        var degrees: [Int]
        switch options.style {
        case .commonProgressions:
            let pick = ProgressionGenerator.namedProgressions.randomElement(using: &seed)!.degrees
            degrees = Array(fit(pick, to: options.length))
        case .pop:
            let loops: [[Int]] = [[1, 5, 6, 4], [6, 4, 1, 5], [1, 6, 4, 5], [4, 1, 5, 6], [1, 4, 6, 5]]
            degrees = Array(fit(loops.randomElement(using: &seed)!, to: options.length))
        case .jazz:
            degrees = jazzChain(length: options.length, seed: &seed)
        case .randomDiatonic:
            degrees = (0..<options.length).map { _ in Int.random(in: 1...7, using: &seed) }
        case .functional:
            degrees = functionalWalk(length: options.length, options: options, seed: &seed)
        }

        if options.startOnTonic, !degrees.isEmpty { degrees[0] = 1 }
        if options.endWithCadence, degrees.count >= 2, options.style != .commonProgressions {
            degrees[degrees.count - 1] = 1
            if degrees.count >= 2 { degrees[degrees.count - 2] = [5, 4, 7].randomElement(using: &seed)! }
        }

        var result: [ProgressionChord] = []
        for (i, deg) in degrees.enumerated() {
            let d = ((deg - 1) % 7 + 7) % 7 + 1
            var pc = ProgressionChord(
                degree: d,
                chord: diatonic[d - 1].chord,
                roman: diatonic[d - 1].roman,
                function: diatonic[d - 1].function
            )

            if options.allowSecondaryDominants, i < degrees.count - 1, d != 1,
               Double.random(in: 0...1, using: &seed) < 0.22 {
                let targetRoot = diatonic[d - 1].chord.root
                pc.chord = Chord(root: targetRoot.transposed(by: 7), quality: options.useSevenths ? .dominant7 : .major)
                pc.roman = "V\(options.useSevenths ? "7" : "")/\(Key.romanBase[d - 1])"
                pc.secondaryOf = d
                pc.function = .dominant
            } else if options.allowBorrowed, Double.random(in: 0...1, using: &seed) < 0.16 {
                applyBorrowed(&pc, key: key, options: options)
            }

            if options.allowInversions, Double.random(in: 0...1, using: &seed) < 0.35 {
                pc.chord.inversion = Int.random(in: 1...(max(1, pc.chord.quality.intervals.count - 1)), using: &seed)
            }
            result.append(pc)
        }
        return Progression(key: key, chords: result)
    }

    /// Re-roll a single unlocked slot, keeping a musical relationship to its neighbours.
    static func reroll(_ progression: Progression, at index: Int, options: ProgressionOptions,
                       seed: inout SplitMix64) -> ProgressionChord {
        let diatonic = progression.key.diatonicChords(sevenths: options.useSevenths)
        let prevDegree = index > 0 ? progression.chords[index - 1].degree : 1
        let choices = transitions[prevDegree] ?? [(1, 1)]
        let deg = weightedPick(choices, seed: &seed)
        let d = ((deg - 1) % 7 + 7) % 7 + 1
        return ProgressionChord(
            degree: d,
            chord: diatonic[d - 1].chord,
            roman: diatonic[d - 1].roman,
            function: diatonic[d - 1].function
        )
    }

    // MARK: - helpers

    private static func functionalWalk(length: Int, options: ProgressionOptions,
                                       seed: inout SplitMix64) -> [Int] {
        var out: [Int] = [options.startOnTonic ? 1 : Int.random(in: 1...7, using: &seed)]
        while out.count < length {
            let prev = out.last!
            let choices = transitions[prev] ?? [(1, 1)]
            out.append(weightedPick(choices, seed: &seed))
        }
        return out
    }

    private static func jazzChain(length: Int, seed: inout SplitMix64) -> [Int] {
        // Chains of ii–V targeting descending-fifth tonics, resolved to I.
        var out: [Int] = []
        let cells: [[Int]] = [[2, 5, 1], [2, 5, 6], [3, 6, 2], [1, 6, 2, 5]]
        while out.count < length {
            out.append(contentsOf: cells.randomElement(using: &seed)!)
        }
        return Array(out.prefix(length))
    }

    private static func applyBorrowed(_ pc: inout ProgressionChord, key: Key, options: ProgressionOptions) {
        // Borrow from the parallel mode: ♭III, ♭VI, ♭VII, iv, ii°.
        let parallelIsMinor = key.scale == .major
        switch pc.degree {
        case 4 where parallelIsMinor:
            pc.chord.quality = options.useSevenths ? .minor7 : .minor
            pc.roman = options.useSevenths ? "iv7" : "iv"; pc.borrowed = true
        case 6 where parallelIsMinor:
            pc.chord = Chord(root: key.tonic.transposed(by: 8), quality: options.useSevenths ? .major7 : .major)
            pc.roman = "♭VI"; pc.borrowed = true
        case 3 where parallelIsMinor:
            pc.chord = Chord(root: key.tonic.transposed(by: 3), quality: .major)
            pc.roman = "♭III"; pc.borrowed = true
        case 7:
            pc.chord = Chord(root: key.tonic.transposed(by: 10), quality: options.useSevenths ? .dominant7 : .major)
            pc.roman = "♭VII"; pc.borrowed = true
        case 2 where parallelIsMinor:
            pc.chord.quality = .diminished
            pc.roman = "ii°"; pc.borrowed = true
        default:
            break
        }
    }

    private static func fit(_ pattern: [Int], to length: Int) -> ArraySlice<Int> {
        if pattern.count == length { return pattern[...] }
        if pattern.count > length { return pattern.prefix(length) }
        var out = pattern
        var i = 0
        while out.count < length { out.append(pattern[i % pattern.count]); i += 1 }
        return out[...]
    }

    private static func weightedPick(_ choices: [(Int, Double)], seed: inout SplitMix64) -> Int {
        let total = choices.reduce(0) { $0 + $1.1 }
        var r = Double.random(in: 0..<total, using: &seed)
        for (value, weight) in choices {
            if r < weight { return value }
            r -= weight
        }
        return choices.last?.0 ?? 1
    }
}

/// Small seedable PRNG so a progression can be reproduced from its seed.
struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
