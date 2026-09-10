import Foundation

enum ScaleType: String, CaseIterable, Identifiable, Codable {
    case major = "Major (Ionian)"
    case naturalMinor = "Natural Minor (Aeolian)"
    case harmonicMinor = "Harmonic Minor"
    case melodicMinor = "Melodic Minor"
    case dorian = "Dorian"
    case phrygian = "Phrygian"
    case lydian = "Lydian"
    case mixolydian = "Mixolydian"
    case locrian = "Locrian"
    case majorPentatonic = "Major Pentatonic"
    case minorPentatonic = "Minor Pentatonic"
    case blues = "Blues"
    case wholeTone = "Whole Tone"
    case chromatic = "Chromatic"

    var id: String { rawValue }

    /// Semitone offsets from the root, ascending within one octave.
    var intervals: [Int] {
        switch self {
        case .major:            return [0, 2, 4, 5, 7, 9, 11]
        case .naturalMinor:     return [0, 2, 3, 5, 7, 8, 10]
        case .harmonicMinor:    return [0, 2, 3, 5, 7, 8, 11]
        case .melodicMinor:     return [0, 2, 3, 5, 7, 9, 11]
        case .dorian:           return [0, 2, 3, 5, 7, 9, 10]
        case .phrygian:         return [0, 1, 3, 5, 7, 8, 10]
        case .lydian:           return [0, 2, 4, 6, 7, 9, 11]
        case .mixolydian:       return [0, 2, 4, 5, 7, 9, 10]
        case .locrian:          return [0, 1, 3, 5, 6, 8, 10]
        case .majorPentatonic:  return [0, 2, 4, 7, 9]
        case .minorPentatonic:  return [0, 3, 5, 7, 10]
        case .blues:            return [0, 3, 5, 6, 7, 10]
        case .wholeTone:        return [0, 2, 4, 6, 8, 10]
        case .chromatic:        return Array(0...11)
        }
    }

    /// Step pattern (W/H) between consecutive scale tones.
    var stepPattern: [Interval] {
        let ints = intervals + [12]
        return zip(ints, ints.dropFirst()).map { Interval(semitones: $1 - $0) }
    }

    var isHeptatonic: Bool { intervals.count == 7 }
    var isDiatonicMode: Bool {
        [.major, .naturalMinor, .dorian, .phrygian, .lydian, .mixolydian, .locrian].contains(self)
    }
    var isMinorish: Bool {
        intervals.contains(3) && !intervals.contains(4)
    }

    /// Scale-degree labels (1, ♭3, ♯4, …) relative to a major reference.
    var degreeLabels: [String] {
        let majorRef = [0, 2, 4, 5, 7, 9, 11]
        return intervals.enumerated().map { idx, semi in
            let degreeIndex = min(idx, majorRef.count - 1)
            let expected = majorRef[degreeIndex]
            let diff = semi - expected
            let acc = diff == 0 ? "" : (diff < 0 ? String(repeating: "♭", count: -diff) : String(repeating: "♯", count: diff))
            return "\(acc)\(degreeIndex + 1)"
        }
    }

    /// The seven diatonic modes that share this scale's parent collection.
    static let diatonicModes: [ScaleType] = [.major, .dorian, .phrygian, .lydian, .mixolydian, .naturalMinor, .locrian]
}

/// A scale rooted on a specific pitch class.
struct Scale: Hashable {
    var root: PitchClass
    var type: ScaleType

    var pitchClasses: [PitchClass] { type.intervals.map { root.transposed(by: $0) } }

    func notes(fromOctave octave: Int, count: Int? = nil) -> [Note] {
        let n = count ?? (type.intervals.count + 1)
        var result: [Note] = []
        let ints = type.intervals
        for i in 0..<n {
            let octaveOffset = i / ints.count
            let semi = ints[i % ints.count] + 12 * octaveOffset
            result.append(Note(root, octave: octave).transposed(by: semi))
        }
        return result
    }

    func contains(_ pc: PitchClass) -> Bool { pitchClasses.contains(pc) }

    /// The scale that begins on this scale's `degree`-th note (1-indexed) — its mode.
    func mode(startingOnDegree degree: Int) -> [PitchClass] {
        let pcs = pitchClasses
        guard !pcs.isEmpty else { return [] }
        let start = (degree - 1) % pcs.count
        return Array(pcs[start...] + pcs[..<start])
    }
}
