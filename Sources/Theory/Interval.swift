import Foundation

/// A musical interval measured in semitones, with a conventional name.
struct Interval: Hashable, Identifiable {
    var semitones: Int
    var id: Int { semitones }

    var shortName: String {
        Interval.names[abs(semitones) % 12].short
    }

    var longName: String {
        let base = Interval.names[abs(semitones) % 12].long
        let octaves = abs(semitones) / 12
        if octaves == 0 { return base }
        return "\(base) + \(octaves) octave\(octaves == 1 ? "" : "s")"
    }

    /// Whole/half-step spelling used by the scale explorer.
    var stepSpelling: String {
        switch semitones {
        case 1: return "H"
        case 2: return "W"
        case 3: return "W+H"
        default: return "\(semitones)st"
        }
    }

    static let names: [(short: String, long: String)] = [
        ("P1", "Perfect unison"),
        ("m2", "Minor 2nd"),
        ("M2", "Major 2nd"),
        ("m3", "Minor 3rd"),
        ("M3", "Major 3rd"),
        ("P4", "Perfect 4th"),
        ("TT", "Tritone"),
        ("P5", "Perfect 5th"),
        ("m6", "Minor 6th"),
        ("M6", "Major 6th"),
        ("m7", "Minor 7th"),
        ("M7", "Major 7th"),
    ]

    static let all: [Interval] = (0...12).map { Interval(semitones: $0) }

    static func between(_ a: Note, _ b: Note) -> Interval { Interval(semitones: abs(b.midi - a.midi)) }
}
