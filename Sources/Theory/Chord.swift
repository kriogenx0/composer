import Foundation

enum ChordQuality: String, CaseIterable, Identifiable, Codable {
    case major = "Major"
    case minor = "Minor"
    case diminished = "Diminished"
    case augmented = "Augmented"
    case sus2 = "Sus2"
    case sus4 = "Sus4"
    case major6 = "6"
    case minor6 = "m6"
    case dominant7 = "7"
    case major7 = "maj7"
    case minor7 = "m7"
    case minorMajor7 = "mMaj7"
    case halfDiminished7 = "m7♭5"
    case diminished7 = "dim7"
    case augmented7 = "7♯5"
    case dominant9 = "9"
    case major9 = "maj9"
    case minor9 = "m9"
    case add9 = "add9"
    case dominant11 = "11"
    case dominant13 = "13"

    var id: String { rawValue }

    /// Semitone offsets from the root.
    var intervals: [Int] {
        switch self {
        case .major:            return [0, 4, 7]
        case .minor:            return [0, 3, 7]
        case .diminished:       return [0, 3, 6]
        case .augmented:        return [0, 4, 8]
        case .sus2:             return [0, 2, 7]
        case .sus4:             return [0, 5, 7]
        case .major6:           return [0, 4, 7, 9]
        case .minor6:           return [0, 3, 7, 9]
        case .dominant7:        return [0, 4, 7, 10]
        case .major7:           return [0, 4, 7, 11]
        case .minor7:           return [0, 3, 7, 10]
        case .minorMajor7:      return [0, 3, 7, 11]
        case .halfDiminished7:  return [0, 3, 6, 10]
        case .diminished7:      return [0, 3, 6, 9]
        case .augmented7:       return [0, 4, 8, 10]
        case .dominant9:        return [0, 4, 7, 10, 14]
        case .major9:           return [0, 4, 7, 11, 14]
        case .minor9:           return [0, 3, 7, 10, 14]
        case .add9:             return [0, 4, 7, 14]
        case .dominant11:       return [0, 4, 7, 10, 14, 17]
        case .dominant13:       return [0, 4, 7, 10, 14, 21]
        }
    }

    /// Symbol suffix appended to a root name, e.g. "m7".
    var symbolSuffix: String {
        switch self {
        case .major:            return ""
        case .minor:            return "m"
        case .diminished:       return "°"
        case .augmented:        return "+"
        case .sus2:             return "sus2"
        case .sus4:             return "sus4"
        case .major6:           return "6"
        case .minor6:           return "m6"
        case .dominant7:        return "7"
        case .major7:           return "maj7"
        case .minor7:           return "m7"
        case .minorMajor7:      return "mMaj7"
        case .halfDiminished7:  return "m7♭5"
        case .diminished7:      return "°7"
        case .augmented7:       return "7♯5"
        case .dominant9:        return "9"
        case .major9:           return "maj9"
        case .minor9:           return "m9"
        case .add9:             return "add9"
        case .dominant11:       return "11"
        case .dominant13:       return "13"
        }
    }

    var formula: String {
        let names = ["1", "♭2", "2", "♭3", "3", "4", "♭5", "5", "♯5", "6", "♭7", "7"]
        return intervals.map { names[$0 % 12] }.joined(separator: " – ")
    }

    var isTriad: Bool { intervals.count == 3 }
    var isSeventh: Bool { intervals.count == 4 }

    /// The seventh-chord version of a plain triad, when one exists.
    var seventhVariant: ChordQuality {
        switch self {
        case .major: return .major7
        case .minor: return .minor7
        case .diminished: return .halfDiminished7
        case .augmented: return .augmented7
        default: return self
        }
    }
}

struct Chord: Hashable, Identifiable {
    var root: PitchClass
    var quality: ChordQuality
    /// 0 = root position, 1 = first inversion, …
    var inversion: Int = 0
    var id: String { "\(root.rawValue)-\(quality.rawValue)-\(inversion)" }

    func symbol(in key: Key? = nil) -> String {
        var s = root.name(in: key) + quality.symbolSuffix
        if inversion > 0 {
            let bass = bassPitchClass
            s += "/" + bass.name(in: key)
        }
        return s
    }

    var pitchClasses: [PitchClass] { quality.intervals.map { root.transposed(by: $0) } }

    var bassPitchClass: PitchClass {
        let idx = inversion % quality.intervals.count
        return root.transposed(by: quality.intervals[idx])
    }

    /// Voiced MIDI notes, applying the inversion by lifting lower voices an octave.
    func notes(octave: Int = 3) -> [Note] {
        var semis = quality.intervals
        for _ in 0..<(inversion % max(1, semis.count)) {
            let first = semis.removeFirst()
            semis.append(first + 12)
        }
        let base = Note(root, octave: octave)
        return semis.map { base.transposed(by: $0) }
    }

    func noteNames(in key: Key? = nil) -> [String] {
        pitchClasses.map { $0.name(in: key) }
    }
}
