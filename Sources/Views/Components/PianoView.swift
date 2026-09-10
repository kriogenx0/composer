import SwiftUI

/// A resizable piano keyboard. Highlights pitch classes or specific MIDI notes,
/// optionally labels notes, and can be played with the mouse.
struct PianoView: View {
    var startNote: Int = 48          // C3
    var octaves: Int = 3
    var highlightedPitchClasses: Set<PitchClass> = []
    var rootPitchClass: PitchClass? = nil
    var highlightedNotes: Set<Int> = []
    var labelStyle: LabelStyle = .none
    var playable: Bool = true
    var key: Key? = nil
    var onPlay: ((Int) -> Void)? = nil

    enum LabelStyle { case none, noteNames, degrees }

    private let whiteOffsets = [0, 2, 4, 5, 7, 9, 11]

    private var whiteNotes: [Int] {
        var result: [Int] = []
        var midi = startNote
        let end = startNote + octaves * 12
        while midi <= end {
            if whiteOffsets.contains(((midi % 12) + 12) % 12) { result.append(midi) }
            midi += 1
        }
        return result
    }

    var body: some View {
        GeometryReader { geo in
            let whiteCount = max(1, whiteNotes.count)
            let whiteWidth = geo.size.width / CGFloat(whiteCount)
            let blackWidth = whiteWidth * 0.62
            let blackHeight = geo.size.height * 0.62

            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    ForEach(whiteNotes, id: \.self) { midi in
                        keyShape(midi: midi, isBlack: false)
                            .frame(width: whiteWidth)
                    }
                }
                ForEach(Array(whiteNotes.enumerated()), id: \.offset) { idx, midi in
                    if hasBlackKeyAfter(midi) {
                        keyShape(midi: midi + 1, isBlack: true)
                            .frame(width: blackWidth, height: blackHeight)
                            .offset(x: whiteWidth * CGFloat(idx + 1) - blackWidth / 2)
                    }
                }
            }
        }
        .frame(minHeight: 90)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
    }

    private func hasBlackKeyAfter(_ midi: Int) -> Bool {
        let pc = ((midi % 12) + 12) % 12
        return [0, 2, 5, 7, 9].contains(pc) && (midi + 1) <= startNote + octaves * 12
    }

    private func keyShape(midi: Int, isBlack: Bool) -> some View {
        let pc = PitchClass(rawValue: ((midi % 12) + 12) % 12)!
        let isHighlighted = highlightedPitchClasses.contains(pc) || highlightedNotes.contains(midi)
        let isRoot = rootPitchClass == pc && isHighlighted

        let fill: Color = {
            if isBlack {
                if isRoot { return .orange }
                return isHighlighted ? Color.accentColor.opacity(0.85) : Color.black
            } else {
                if isRoot { return .orange.opacity(0.85) }
                return isHighlighted ? Color.accentColor.opacity(0.35) : Color.white
            }
        }()

        return Rectangle()
            .fill(fill)
            .overlay(alignment: .bottom) {
                if labelStyle != .none, let text = label(for: pc, midi: midi) {
                    Text(text)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(isBlack ? .white : .black)
                        .padding(.bottom, 3)
                }
            }
            .overlay(Rectangle().stroke(Color.black.opacity(isBlack ? 0 : 0.25), lineWidth: 0.5))
            .contentShape(Rectangle())
            .onTapGesture {
                guard playable else { return }
                AudioEngine.shared.play(midi: midi, duration: 0.5)
                onPlay?(midi)
            }
    }

    private func label(for pc: PitchClass, midi: Int) -> String? {
        switch labelStyle {
        case .none: return nil
        case .noteNames: return pc.name(in: key)
        case .degrees:
            guard let root = rootPitchClass else { return nil }
            let semi = ((pc.rawValue - root.rawValue) + 12) % 12
            let names = ["1", "♭2", "2", "♭3", "3", "4", "♭5", "5", "♭6", "6", "♭7", "7"]
            return highlightedPitchClasses.contains(pc) ? names[semi] : nil
        }
    }
}
