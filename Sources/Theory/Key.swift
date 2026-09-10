import Foundation

enum HarmonicFunction: String, Codable {
    case tonic = "Tonic"
    case predominant = "Predominant"
    case dominant = "Dominant"

    var abbreviation: String {
        switch self {
        case .tonic: return "T"
        case .predominant: return "PD"
        case .dominant: return "D"
        }
    }
}

struct DiatonicChord: Identifiable, Hashable {
    var degree: Int          // 1...7
    var chord: Chord
    var roman: String
    var function: HarmonicFunction
    var id: Int { degree }
}

struct Key: Hashable, Identifiable, Codable {
    var tonic: PitchClass
    var scale: ScaleType
    /// Force flat/sharp spelling; when nil a sensible default is chosen.
    var preferFlatSpelling: Bool?

    var id: String { "\(tonic.rawValue)-\(scale.rawValue)" }

    init(tonic: PitchClass, scale: ScaleType = .major, preferFlatSpelling: Bool? = nil) {
        self.tonic = tonic
        self.scale = scale
        self.preferFlatSpelling = preferFlatSpelling
    }

    var scaleModel: Scale { Scale(root: tonic, type: scale) }

    // MARK: Spelling

    var prefersFlats: Bool {
        if let preferFlatSpelling { return preferFlatSpelling }
        return signature.isFlat && signature.count > 0
    }

    var name: String {
        let root = prefersFlats ? tonic.flatName : tonic.sharpName
        return "\(root) \(scale.rawValue)"
    }

    var shortName: String {
        let root = prefersFlats ? tonic.flatName : tonic.sharpName
        if scale == .major { return root }
        if scale == .naturalMinor { return "\(root)m" }
        return "\(root) \(scale.rawValue)"
    }

    // MARK: Key signature

    /// Clockwise distance from C in perfect fifths (0 = C, 1 = G, … 11 = F).
    static let fifthsOrder: [PitchClass] =
        [.c, .g, .d, .a, .e, .b, .fSharp, .cSharp, .gSharp, .dSharp, .aSharp, .f]

    static func fifthsFromC(_ pc: PitchClass) -> Int {
        fifthsOrder.firstIndex(of: pc) ?? 0
    }

    /// (count, isFlat). Derived from the equivalent major key on the circle of fifths.
    /// C…F♯ read as 0–6 sharps; the far side (C♯…F) reads as 5–1 flats (D♭, A♭, E♭, B♭, F).
    var signature: (count: Int, isFlat: Bool) {
        let n = Key.fifthsFromC(equivalentMajorRoot)
        if n <= 6 { return (n, false) }
        return (12 - n, true)
    }

    var signatureText: String {
        let s = signature
        if s.count == 0 { return "no sharps or flats" }
        return "\(s.count) \(s.isFlat ? "flat" : "sharp")\(s.count == 1 ? "" : "s")"
    }

    /// Ordered accidental note names implied by the signature (e.g. F♯, C♯ …).
    var accidentalNames: [String] {
        let s = signature
        let sharps = ["F♯", "C♯", "G♯", "D♯", "A♯", "E♯", "B♯"]
        let flats  = ["B♭", "E♭", "A♭", "D♭", "G♭", "C♭", "F♭"]
        return Array((s.isFlat ? flats : sharps).prefix(s.count))
    }

    /// Root of the major key sharing this key's signature.
    var equivalentMajorRoot: PitchClass {
        let diatonicOffsets: [ScaleType: Int] = [
            .major: 0, .dorian: 2, .phrygian: 4, .lydian: 5,
            .mixolydian: 7, .naturalMinor: 9, .locrian: 11,
        ]
        if let off = diatonicOffsets[scale] {
            return tonic.transposed(by: -off)
        }
        // Minor-ish scales borrow the natural-minor relationship; others map to themselves.
        if scale.isMinorish { return tonic.transposed(by: 3) }
        return tonic
    }

    var relativeKey: Key {
        if scale == .major { return Key(tonic: tonic.transposed(by: 9), scale: .naturalMinor) }
        if scale == .naturalMinor { return Key(tonic: tonic.transposed(by: 3), scale: .major) }
        return Key(tonic: equivalentMajorRoot, scale: .major)
    }

    var parallelKey: Key {
        Key(tonic: tonic, scale: scale == .major ? .naturalMinor : .major)
    }

    // MARK: Diatonic harmony

    static let romanBase = ["I", "II", "III", "IV", "V", "VI", "VII"]

    func diatonicChords(sevenths: Bool = false) -> [DiatonicChord] {
        let pcs = scaleModel.pitchClasses
        guard pcs.count == 7 else { return [] }
        var result: [DiatonicChord] = []
        for degree in 0..<7 {
            let stackSize = sevenths ? 4 : 3
            let chordPCs = (0..<stackSize).map { pcs[(degree + $0 * 2) % 7] }
            let quality = Key.identifyQuality(rootRelative: chordPCs)
            let chord = Chord(root: pcs[degree], quality: quality)
            let roman = Key.romanNumeral(base: Key.romanBase[degree], quality: quality, sevenths: sevenths)
            result.append(DiatonicChord(
                degree: degree + 1,
                chord: chord,
                roman: roman,
                function: Key.functionFor(degree: degree + 1, minor: scale.isMinorish)
            ))
        }
        return result
    }

    static func identifyQuality(rootRelative pcs: [PitchClass]) -> ChordQuality {
        guard let root = pcs.first else { return .major }
        let semis = pcs.map { ($0.rawValue - root.rawValue + 12) % 12 }.sorted()
        let set = Set(semis)
        if set.isSuperset(of: [0, 4, 7]) {
            if set.contains(11) { return .major7 }
            if set.contains(10) { return .dominant7 }
            return .major
        }
        if set.isSuperset(of: [0, 3, 7]) {
            if set.contains(10) { return .minor7 }
            if set.contains(11) { return .minorMajor7 }
            return .minor
        }
        if set.isSuperset(of: [0, 3, 6]) {
            if set.contains(10) { return .halfDiminished7 }
            if set.contains(9) { return .diminished7 }
            return .diminished
        }
        if set.isSuperset(of: [0, 4, 8]) { return .augmented }
        return .major
    }

    static func romanNumeral(base: String, quality: ChordQuality, sevenths: Bool) -> String {
        var numeral = base
        switch quality {
        case .minor, .minor7, .minor6, .minor9, .minorMajor7:
            numeral = base.lowercased()
        case .diminished, .halfDiminished7, .diminished7:
            numeral = base.lowercased()
        case .augmented, .augmented7:
            break // stays uppercase, gets a +
        default:
            break
        }
        switch quality {
        case .diminished: numeral += "°"
        case .halfDiminished7: numeral += "ø7"
        case .diminished7: numeral += "°7"
        case .augmented, .augmented7: numeral += "+"
        case .major7: numeral += sevenths ? "maj7" : ""
        case .dominant7, .minor7: numeral += sevenths ? "7" : ""
        default: break
        }
        return numeral
    }

    static func functionFor(degree: Int, minor: Bool) -> HarmonicFunction {
        switch degree {
        case 1, 3, 6: return .tonic
        case 2, 4: return .predominant
        case 5, 7: return .dominant
        default: return .tonic
        }
    }

    // MARK: Circle of fifths

    /// Clockwise position on the wheel (0 = C / A minor).
    var circlePosition: Int { Key.fifthsFromC(equivalentMajorRoot) }

    static let circleOfFifthsMajors: [Key] = {
        let roots: [(PitchClass, Bool?)] = [
            (.c, false), (.g, false), (.d, false), (.a, false), (.e, false), (.b, false),
            (.fSharp, false), (.cSharp, true), (.gSharp, true), (.dSharp, true), (.aSharp, true), (.f, true),
        ]
        return roots.map { Key(tonic: $0.0, scale: .major, preferFlatSpelling: $0.1) }
    }()
}
