import Foundation

/// A pitch class: an integer 0...11 where C = 0. Octave-independent.
enum PitchClass: Int, CaseIterable, Identifiable, Hashable, Codable {
    case c = 0, cSharp, d, dSharp, e, f, fSharp, g, gSharp, a, aSharp, b

    var id: Int { rawValue }

    /// Sharp-oriented name.
    var sharpName: String {
        ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"][rawValue]
    }

    /// Flat-oriented name.
    var flatName: String {
        ["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"][rawValue]
    }

    /// Name chosen to fit a key context (uses the key's preferred accidental).
    func name(in key: Key? = nil) -> String {
        guard let key else { return sharpName }
        return key.prefersFlats ? flatName : sharpName
    }

    func transposed(by semitones: Int) -> PitchClass {
        PitchClass(rawValue: ((rawValue + semitones) % 12 + 12) % 12)!
    }

    static func + (lhs: PitchClass, rhs: Int) -> PitchClass { lhs.transposed(by: rhs) }
}

/// A concrete pitch = MIDI note number (0...127). Middle C (C4) = 60.
struct Note: Hashable, Codable, Comparable, Identifiable {
    var midi: Int
    var id: Int { midi }

    init(midi: Int) { self.midi = max(0, min(127, midi)) }

    init(_ pitchClass: PitchClass, octave: Int) {
        self.midi = (octave + 1) * 12 + pitchClass.rawValue
    }

    var pitchClass: PitchClass { PitchClass(rawValue: ((midi % 12) + 12) % 12)! }
    var octave: Int { midi / 12 - 1 }

    func name(in key: Key? = nil, withOctave: Bool = true) -> String {
        let n = pitchClass.name(in: key)
        return withOctave ? "\(n)\(octave)" : n
    }

    /// Concert pitch frequency (A4 = 440 Hz).
    var frequency: Double { 440.0 * pow(2.0, Double(midi - 69) / 12.0) }

    func transposed(by semitones: Int) -> Note { Note(midi: midi + semitones) }

    static func < (lhs: Note, rhs: Note) -> Bool { lhs.midi < rhs.midi }
}
