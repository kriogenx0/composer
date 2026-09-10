import SwiftUI

struct CircleOfFifthsView: View {
    @EnvironmentObject var state: AppState
    @State private var selectedPosition: Int = 0
    @State private var hoverPosition: Int? = nil

    private var majors: [Key] { Key.circleOfFifthsMajors }

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            wheel
                .frame(width: 420, height: 420)
                .padding(.top, 8)

            infoPanel
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        .navigationTitle("Circle of Fifths")
        .onAppear { selectedPosition = state.key.circlePosition }
        .onChange(of: state.tonic) { _, _ in selectedPosition = state.key.circlePosition }
        .onChange(of: state.scaleType) { _, _ in selectedPosition = state.key.circlePosition }
    }

    // MARK: Wheel

    private var wheel: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let rOuter = size * 0.48
            let rMid = size * 0.34
            let rInner = size * 0.20

            ZStack {
                ForEach(0..<12, id: \.self) { pos in
                    segment(pos: pos, center: center, rOuter: rOuter, rMid: rMid, rInner: rInner)
                }
                Circle().stroke(.quaternary).frame(width: rInner * 2)
                Text("♯  →").font(.caption2).foregroundStyle(.secondary)
                    .offset(x: size * 0.30, y: -size * 0.44)
                Text("←  ♭").font(.caption2).foregroundStyle(.secondary)
                    .offset(x: -size * 0.30, y: -size * 0.44)
            }
        }
    }

    private func segment(pos: Int, center: CGPoint, rOuter: CGFloat, rMid: CGFloat, rInner: CGFloat) -> some View {
        let angle = Angle.degrees(Double(pos) / 12 * 360 - 90)
        let startAngle = Angle.degrees(Double(pos) / 12 * 360 - 90 - 15)
        let endAngle = Angle.degrees(Double(pos) / 12 * 360 - 90 + 15)
        let key = majors[pos]
        let isSelected = pos == selectedPosition
        let isRelated = relatedPositions(to: selectedPosition).contains(pos)
        let inProgression = progressionPositions().contains(pos)

        return ZStack {
            RingSlice(center: center, innerRadius: rMid, outerRadius: rOuter,
                      startAngle: startAngle, endAngle: endAngle)
                .fill(segmentColor(isSelected: isSelected, isRelated: isRelated, inProgression: inProgression, inner: false))
                .overlay(RingSlice(center: center, innerRadius: rMid, outerRadius: rOuter,
                                   startAngle: startAngle, endAngle: endAngle).stroke(.background, lineWidth: 2))
            RingSlice(center: center, innerRadius: rInner, outerRadius: rMid,
                      startAngle: startAngle, endAngle: endAngle)
                .fill(segmentColor(isSelected: isSelected, isRelated: isRelated, inProgression: inProgression, inner: true))
                .overlay(RingSlice(center: center, innerRadius: rInner, outerRadius: rMid,
                                   startAngle: startAngle, endAngle: endAngle).stroke(.background, lineWidth: 2))

            label(key.shortName, at: angle, radius: (rMid + rOuter) / 2, center: center,
                  bold: isSelected)
            label(key.relativeKey.shortName, at: angle, radius: (rInner + rMid) / 2, center: center,
                  bold: isSelected, small: true)
        }
        .contentShape(RingSlice(center: center, innerRadius: rInner, outerRadius: rOuter,
                                startAngle: startAngle, endAngle: endAngle))
        .onTapGesture {
            selectedPosition = pos
            AudioEngine.shared.playChord(key.diatonicChords().first!.chord.notes(octave: 3))
        }
    }

    private func label(_ text: String, at angle: Angle, radius: CGFloat, center: CGPoint,
                       bold: Bool, small: Bool = false) -> some View {
        Text(text)
            .font(small ? .caption2 : .callout)
            .fontWeight(bold ? .bold : .regular)
            .position(x: center.x + radius * CGFloat(cos(angle.radians)),
                      y: center.y + radius * CGFloat(sin(angle.radians)))
    }

    private func segmentColor(isSelected: Bool, isRelated: Bool, inProgression: Bool, inner: Bool) -> Color {
        if isSelected { return inner ? Color.accentColor.opacity(0.55) : Color.accentColor.opacity(0.8) }
        if inProgression { return Color.orange.opacity(inner ? 0.35 : 0.5) }
        if isRelated { return Color.accentColor.opacity(inner ? 0.12 : 0.2) }
        return inner ? Color.secondary.opacity(0.12) : Color.secondary.opacity(0.22)
    }

    // MARK: Info panel

    private var infoPanel: some View {
        let key = majors[selectedPosition]
        let selectedIsMinorContext = state.scaleType.isMinorish
        let displayKey = selectedIsMinorContext ? key.relativeKey : key
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(displayKey.name).font(.title2.bold())
                Spacer()
                Button("Load into working key") {
                    state.tonic = displayKey.tonic
                    state.scaleType = displayKey.scale
                    state.regenerate()
                }
            }
            infoRow("Key signature", key.signatureText)
            if !key.accidentalNames.isEmpty {
                infoRow("Accidentals", key.accidentalNames.joined(separator: ", "))
            }
            infoRow("Relative minor", key.relativeKey.shortName)
            infoRow("Parallel minor", key.parallelKey.shortName)
            infoRow("Dominant (next ♯)", majors[(selectedPosition + 1) % 12].shortName)
            infoRow("Subdominant (next ♭)", majors[(selectedPosition + 11) % 12].shortName)

            Divider()
            Text("Diatonic triads").font(.headline)
            ForEach(displayKey.diatonicChords(sevenths: state.options.useSevenths)) { dc in
                HStack {
                    Text(dc.roman).frame(width: 60, alignment: .leading).bold()
                    Text(dc.chord.symbol(in: displayKey)).frame(width: 80, alignment: .leading)
                    Text(dc.chord.noteNames(in: displayKey).joined(separator: " · "))
                        .foregroundStyle(.secondary).font(.callout)
                    Spacer()
                    Button {
                        AudioEngine.shared.playChord(dc.chord.notes(octave: 3))
                    } label: { Image(systemName: "play.circle") }
                    .buttonStyle(.borderless)
                }
                .font(.callout)
            }

            Divider()
            Text("The three chords next to each other on the wheel (IV–I–V) are the primary chords of a key. "
                 + "Neighbouring keys differ by just one accidental — the basis of smooth modulation.")
                .font(.callout).foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary).frame(width: 150, alignment: .leading)
            Text(value)
        }
        .font(.callout)
    }

    // MARK: Highlighting helpers

    private func relatedPositions(to pos: Int) -> Set<Int> {
        [(pos + 1) % 12, (pos + 11) % 12]
    }

    private func progressionPositions() -> Set<Int> {
        guard let progression = state.progression else { return [] }
        return Set(progression.chords.map {
            Key(tonic: $0.chord.root, scale: .major).circlePosition
        })
    }
}

/// A pie/ring slice shape.
struct RingSlice: Shape {
    var center: CGPoint
    var innerRadius: CGFloat
    var outerRadius: CGFloat
    var startAngle: Angle
    var endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: center, radius: outerRadius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        p.addArc(center: center, radius: innerRadius, startAngle: endAngle, endAngle: startAngle, clockwise: true)
        p.closeSubpath()
        return p
    }
}
