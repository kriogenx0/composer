import SwiftUI

/// Editable step sequencer grid for a one-bar rhythm.
/// Click toggles a step; ⌥-click toggles accent; ⇧-click toggles a tie.
struct StepGridView: View {
    @Binding var pattern: RhythmPattern

    var body: some View {
        GeometryReader { geo in
            let count = max(1, pattern.steps.count)
            let spacing: CGFloat = 4
            let cellW = (geo.size.width - spacing * CGFloat(count - 1)) / CGFloat(count)
            let perBeat = pattern.stepsPerBeat

            HStack(spacing: spacing) {
                ForEach(Array(pattern.steps.enumerated()), id: \.offset) { i, step in
                    let isBeatStart = i % max(1, perBeat) == 0
                    VStack(spacing: 3) {
                        Text(isBeatStart ? "\(i / max(1, perBeat) + 1)" : "·")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(fill(for: step, isBeatStart: isBeatStart))
                            if step.tie {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                            if step.accent {
                                VStack { Rectangle().fill(.white).frame(height: 3); Spacer() }
                                    .padding(2)
                            }
                        }
                        .frame(width: cellW)
                        .contentShape(Rectangle())
                        .onTapGesture { toggle(i, modifiers: currentModifiers) }
                    }
                }
            }
            .background(
                // capture modifier keys
                KeyModifierReader { currentModifiers = $0 }
            )
        }
    }

    @State private var currentModifiers: EventModifiers = []

    private func fill(for step: RhythmStep, isBeatStart: Bool) -> Color {
        if step.active { return step.accent ? .orange : Color.accentColor }
        return isBeatStart ? Color.secondary.opacity(0.28) : Color.secondary.opacity(0.14)
    }

    private func toggle(_ i: Int, modifiers: EventModifiers) {
        guard i < pattern.steps.count else { return }
        if modifiers.contains(.option) {
            pattern.steps[i].accent.toggle()
            if pattern.steps[i].accent { pattern.steps[i].active = true }
        } else if modifiers.contains(.shift) {
            pattern.steps[i].tie.toggle()
        } else {
            pattern.steps[i].active.toggle()
            if !pattern.steps[i].active { pattern.steps[i].accent = false }
        }
    }
}

/// Invisible view that reports the current keyboard modifier flags.
struct KeyModifierReader: NSViewRepresentable {
    var onChange: (EventModifiers) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = TrackingView()
        view.onChange = onChange
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}

    final class TrackingView: NSView {
        var onChange: ((EventModifiers) -> Void)?
        private var monitor: Any?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
                var mods: EventModifiers = []
                if event.modifierFlags.contains(.option) { mods.insert(.option) }
                if event.modifierFlags.contains(.shift) { mods.insert(.shift) }
                if event.modifierFlags.contains(.command) { mods.insert(.command) }
                self?.onChange?(mods)
                return event
            }
        }
        deinit { if let monitor { NSEvent.removeMonitor(monitor) } }
    }
}
