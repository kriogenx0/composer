import SwiftUI

/// A top-level area of the app, shown in the sidebar and grouped by `SidebarGroup`.
enum Feature: String, CaseIterable, Identifiable {
    case progressions = "Chord Progressions"
    case rhythm = "Rhythm & Syncopation"
    case circleOfFifths = "Circle of Fifths"
    case scales = "Scales & Modes"
    case chords = "Chord Dictionary"
    case piano = "Piano"
    case ear = "Ear Training"
    case metronome = "Metronome"
    case polyrhythm = "Polyrhythm"
    case reference = "Reference"

    var id: String { rawValue }

    var group: SidebarGroup {
        switch self {
        case .progressions, .rhythm:                      return .create
        case .circleOfFifths, .scales, .chords:           return .explore
        case .piano, .ear, .metronome, .polyrhythm:       return .practice
        case .reference:                                  return .learn
        }
    }

    var systemImage: String {
        switch self {
        case .progressions:   return "square.stack.3d.up"
        case .rhythm:         return "waveform.path"
        case .circleOfFifths: return "circle.hexagongrid"
        case .scales:         return "pianokeys.inverse"
        case .chords:         return "music.note.list"
        case .piano:          return "pianokeys"
        case .ear:            return "ear"
        case .metronome:      return "metronome"
        case .polyrhythm:     return "circle.circle"
        case .reference:      return "book"
        }
    }

    var blurb: String {
        switch self {
        case .progressions:   return "Generate and export chord progressions"
        case .rhythm:         return "Grooves, subdivisions and syncopation"
        case .circleOfFifths: return "Keys, signatures and relationships"
        case .scales:         return "Scales, modes and their character"
        case .chords:         return "Build and hear any chord"
        case .piano:          return "A playable keyboard"
        case .ear:            return "Interval, chord and cadence drills"
        case .metronome:      return "Tempo, tap tempo and subdivisions"
        case .polyrhythm:     return "A rotating geometric polyrhythm wheel"
        case .reference:      return "Theory cards and glossary"
        }
    }
}

enum SidebarGroup: String, CaseIterable, Identifiable {
    case create = "Create"
    case explore = "Explore"
    case practice = "Practice"
    case learn = "Learn"

    var id: String { rawValue }
    var features: [Feature] { Feature.allCases.filter { $0.group == self } }
}

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @State private var selection: Feature = .progressions

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(SidebarGroup.allCases) { group in
                    Section(group.rawValue) {
                        ForEach(group.features) { feature in
                            Label(feature.rawValue, systemImage: feature.systemImage)
                                .tag(feature)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 215, ideal: 235, max: 300)
            .safeAreaInset(edge: .bottom) { KeyBar() }
        } detail: {
            Group {
                switch selection {
                case .progressions:   ProgressionView()
                case .rhythm:         RhythmView()
                case .circleOfFifths: CircleOfFifthsView()
                case .scales:         ScaleExplorerView()
                case .chords:         ChordDictionaryView()
                case .piano:          PianoStudioView()
                case .ear:            EarTrainingView()
                case .metronome:      MetronomeView()
                case .polyrhythm:     PolyrhythmView()
                case .reference:      ReferenceView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Persistent key/scale picker shown at the bottom of the sidebar.
struct KeyBar: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Text("WORKING KEY").font(.caption2).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Picker("", selection: $state.tonic) {
                    ForEach(PitchClass.allCases) { pc in
                        Text(pc.name(in: state.key)).tag(pc)
                    }
                }
                .labelsHidden()
                .frame(width: 62)

                Picker("", selection: $state.scaleType) {
                    ForEach(ScaleType.allCases) { st in
                        Text(st.rawValue).tag(st)
                    }
                }
                .labelsHidden()
            }
            Text(state.key.signatureText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .onChange(of: state.tonic) { _, _ in state.regenerate() }
        .onChange(of: state.scaleType) { _, _ in state.regenerate() }
    }
}
