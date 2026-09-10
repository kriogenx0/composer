import SwiftUI

struct ReferenceView: View {
    @State private var query = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Reference").font(.title2.bold())
                TextField("Filter cards & glossary…", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 320)

                ForEach(Self.cards.filter { matches($0) }) { card in
                    RefCard(card: card)
                }

                if glossaryMatches.count > 0 {
                    Text("Glossary").font(.headline).padding(.top, 6)
                    ForEach(glossaryMatches, id: \.term) { entry in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.term).font(.callout.bold())
                            Text(entry.definition).font(.callout).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
            .padding(22)
        }
        .navigationTitle("Reference")
    }

    private func matches(_ card: RefCardModel) -> Bool {
        guard !query.isEmpty else { return true }
        let q = query.lowercased()
        return card.title.lowercased().contains(q)
            || card.body.lowercased().contains(q)
            || card.rows.contains { $0.0.lowercased().contains(q) || $0.1.lowercased().contains(q) }
    }

    private var glossaryMatches: [(term: String, definition: String)] {
        guard !query.isEmpty else { return Self.glossary }
        let q = query.lowercased()
        return Self.glossary.filter { $0.term.lowercased().contains(q) || $0.definition.lowercased().contains(q) }
    }

    // MARK: Content

    static let cards: [RefCardModel] = [
        RefCardModel(
            title: "Functional harmony (T – PD – D)",
            body: "Chords group by role. Tonic (I, vi, iii) is home. Predominant (ii, IV) moves away. "
                + "Dominant (V, vii°) creates tension that resolves back to tonic. Most progressions cycle T → PD → D → T.",
            rows: [
                ("Tonic", "I, vi, iii — stability, rest"),
                ("Predominant", "ii, IV — motion, sets up the dominant"),
                ("Dominant", "V, vii° — tension, leading tone pulls to I"),
            ]),
        RefCardModel(
            title: "Cadences",
            body: "A cadence is a harmonic punctuation mark closing a phrase.",
            rows: [
                ("Authentic (perfect)", "V → I, both in root position, melody ends on tonic — a full stop"),
                ("Plagal", "IV → I — the 'Amen' cadence, gentler"),
                ("Half", "ends on V — a comma, expects continuation"),
                ("Deceptive", "V → vi — the resolution is dodged"),
            ]),
        RefCardModel(
            title: "Intervals",
            body: "Distance between two pitches, by number (2nd, 3rd…) and quality (major, minor, perfect…).",
            rows: [
                ("m2 / M2", "1 / 2 semitones"),
                ("m3 / M3", "3 / 4 semitones"),
                ("P4 / TT / P5", "5 / 6 / 7 semitones"),
                ("m6 / M6", "8 / 9 semitones"),
                ("m7 / M7 / P8", "10 / 11 / 12 semitones"),
            ]),
        RefCardModel(
            title: "Chord construction",
            body: "Triads stack two thirds; seventh chords add a third on top. Quality depends on which thirds (major = 4 semitones, minor = 3).",
            rows: [
                ("Major", "root + M3 + m3  (1 3 5)"),
                ("Minor", "root + m3 + M3  (1 ♭3 5)"),
                ("Diminished", "root + m3 + m3  (1 ♭3 ♭5)"),
                ("Augmented", "root + M3 + M3  (1 3 ♯5)"),
                ("Dominant 7", "major triad + m7  (1 3 5 ♭7)"),
                ("Major 7", "major triad + M7  (1 3 5 7)"),
                ("Minor 7", "minor triad + m7  (1 ♭3 5 ♭7)"),
            ]),
        RefCardModel(
            title: "Key signatures — order of accidentals",
            body: "Sharps add in fifths up: F C G D A E B ('Father Charles Goes Down And Ends Battle'). "
                + "Flats are the reverse: B E A D G C F. Major key = last sharp + a semitone; second-to-last flat names the key.",
            rows: [
                ("0", "C major / A minor"),
                ("1♯…7♯", "G D A E B F♯ C♯"),
                ("1♭…7♭", "F B♭ E♭ A♭ D♭ G♭ C♭"),
            ]),
        RefCardModel(
            title: "Common progressions",
            body: "Reusable harmonic templates heard across thousands of songs.",
            rows: [
                ("I–V–vi–IV", "the 'axis' / four-chord pop loop"),
                ("ii–V–I", "the fundamental jazz cadence"),
                ("I–vi–IV–V", "1950s doo-wop"),
                ("12-bar blues", "I·I·I·I · IV·IV·I·I · V·IV·I·V"),
                ("i–♭VII–♭VI–V", "Andalusian / flamenco descent"),
            ]),
        RefCardModel(
            title: "Rhythm terms",
            body: "How events are placed in time.",
            rows: [
                ("Beat / pulse", "the steady underlying count"),
                ("Subdivision", "dividing the beat into 2s (eighths), 4s (sixteenths) or 3s (triplets)"),
                ("Syncopation", "accent on a weak beat or off-beat, against the expected pulse"),
                ("Swing", "delaying every other subdivision for a long–short feel"),
                ("Anticipation", "a note arriving just before its beat, tied over"),
                ("Hemiola", "3 in the time of 2 (or vice-versa)"),
                ("Polyrhythm", "two conflicting pulses at once, e.g. 3 against 4"),
            ]),
        RefCardModel(
            title: "Song forms",
            body: "Large-scale arrangement of sections.",
            rows: [
                ("AABA", "32-bar standard / show-tune form"),
                ("Verse–Chorus", "modern pop backbone, often + pre-chorus & bridge"),
                ("12-bar blues", "repeating 12-bar harmonic cycle"),
                ("Through-composed", "no large repeats; continuously new material"),
            ]),
        RefCardModel(
            title: "The modes at a glance",
            body: "Rotations of the major scale, ordered brightest to darkest.",
            rows: [
                ("Lydian", "major + ♯4 — brightest"),
                ("Ionian", "the major scale"),
                ("Mixolydian", "major + ♭7 — dominant, bluesy"),
                ("Dorian", "minor + ♮6 — hopeful minor"),
                ("Aeolian", "the natural minor scale"),
                ("Phrygian", "minor + ♭2 — Spanish, dark"),
                ("Locrian", "minor + ♭2 + ♭5 — unstable"),
            ]),
    ]

    static let glossary: [(term: String, definition: String)] = [
        ("Arpeggio", "The notes of a chord played one after another rather than together."),
        ("Diatonic", "Belonging to the seven notes of the prevailing key, with no added accidentals."),
        ("Chromatic", "Moving by semitones / using notes outside the key."),
        ("Leading tone", "The 7th degree of a major or harmonic-minor scale, a semitone below the tonic, pulling upward."),
        ("Voice leading", "How individual notes move from one chord to the next, ideally by small steps."),
        ("Inversion", "A chord with a note other than the root in the bass."),
        ("Secondary dominant", "A dominant 7th chord borrowed to tonicise a chord other than I, e.g. V7/V."),
        ("Borrowed chord", "A chord taken from the parallel major or minor key for colour, e.g. iv in a major key."),
        ("Modulation", "Changing key within a piece."),
        ("Cadence", "A harmonic formula that ends a phrase (see the Cadences card)."),
        ("Tonic", "The home note and chord of a key; where music feels at rest."),
        ("Dominant", "The 5th degree; its chord (V) creates the strongest pull back to the tonic."),
        ("Tritone", "Three whole tones (6 semitones); the unstable interval inside every dominant 7th."),
        ("Pentatonic", "A five-note scale; major or minor, with no semitones, hence very consonant."),
        ("Syncopation", "Rhythmic emphasis that contradicts the regular pulse."),
        ("Ostinato", "A short musical pattern repeated persistently."),
        ("Cadential 6-4", "A tonic chord in second inversion on a strong beat, delaying and intensifying the dominant."),
    ]
}

struct RefCardModel: Identifiable {
    let id = UUID()
    let title: String
    let body: String
    let rows: [(String, String)]
}

struct RefCard: View {
    let card: RefCardModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(card.title).font(.headline)
            Text(card.body).font(.callout).foregroundStyle(.secondary)
            if !card.rows.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(card.rows.enumerated()), id: \.offset) { _, row in
                        HStack(alignment: .top) {
                            Text(row.0).frame(width: 150, alignment: .leading).bold().font(.callout)
                            Text(row.1).font(.callout).foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.4)))
    }
}
