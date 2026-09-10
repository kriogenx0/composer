import Foundation

/// Minimal Standard MIDI File (SMF) writer — format 1, tempo track + note tracks.
struct MIDIFile {
    var ppq: Int = 480
    var tracks: [MIDITrack] = []

    struct MIDIEvent {
        var tick: Int          // absolute tick
        var order: Int         // tie-breaker so note-offs precede note-ons at the same tick
        var bytes: [UInt8]     // status + data (no delta time)
    }

    struct MIDITrack {
        var name: String = ""
        var events: [MIDIEvent] = []

        mutating func addNote(channel: UInt8, note: UInt8, velocity: UInt8, start: Int, duration: Int) {
            let dur = max(1, duration)
            events.append(.init(tick: start, order: 1,
                                bytes: [0x90 | (channel & 0x0F), note & 0x7F, velocity & 0x7F]))
            events.append(.init(tick: start + dur, order: 0,
                                bytes: [0x80 | (channel & 0x0F), note & 0x7F, 0]))
        }

        mutating func addProgramChange(channel: UInt8, program: UInt8, tick: Int = 0) {
            events.append(.init(tick: tick, order: -1, bytes: [0xC0 | (channel & 0x0F), program & 0x7F]))
        }
    }

    func encoded(tempoBPM: Double, timeSignature: TimeSignature) -> Data {
        var data = Data()
        // ---- Header chunk ----
        data.append(contentsOf: Array("MThd".utf8))
        data.append(uint32: 6)
        data.append(uint16: 1)                                   // format 1
        data.append(uint16: UInt16(tracks.count + 1))            // + tempo track
        data.append(uint16: UInt16(ppq))

        // ---- Tempo / meta track ----
        var tempoTrack = MIDITrack(name: "Tempo")
        let mpqn = Int(60_000_000.0 / max(1, tempoBPM))
        tempoTrack.events.append(.init(tick: 0, order: -2, bytes: [
            0xFF, 0x51, 0x03,
            UInt8((mpqn >> 16) & 0xFF), UInt8((mpqn >> 8) & 0xFF), UInt8(mpqn & 0xFF),
        ]))
        let denPow = UInt8(log2(Double(timeSignature.denominator)).rounded())
        tempoTrack.events.append(.init(tick: 0, order: -2, bytes: [
            0xFF, 0x58, 0x04, UInt8(timeSignature.numerator), denPow, 24, 8,
        ]))
        data.append(encodeTrack(tempoTrack))

        for track in tracks { data.append(encodeTrack(track)) }
        return data
    }

    private func encodeTrack(_ track: MIDITrack) -> Data {
        var body = Data()
        if !track.name.isEmpty {
            let nameBytes = Array(track.name.utf8)
            body.append(contentsOf: [0x00, 0xFF, 0x03])
            body.append(varLen: nameBytes.count)
            body.append(contentsOf: nameBytes)
        }
        let sorted = track.events.sorted {
            $0.tick != $1.tick ? $0.tick < $1.tick : $0.order < $1.order
        }
        var lastTick = 0
        for event in sorted {
            let delta = max(0, event.tick - lastTick)
            body.append(varLen: delta)
            body.append(contentsOf: event.bytes)
            lastTick = event.tick
        }
        body.append(contentsOf: [0x00, 0xFF, 0x2F, 0x00])   // end of track

        var chunk = Data()
        chunk.append(contentsOf: Array("MTrk".utf8))
        chunk.append(uint32: UInt32(body.count))
        chunk.append(body)
        return chunk
    }
}

private extension Data {
    mutating func append(uint16 value: UInt16) {
        append(contentsOf: [UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)])
    }
    mutating func append(uint32 value: UInt32) {
        append(contentsOf: [
            UInt8((value >> 24) & 0xFF), UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF),
        ])
    }
    /// Variable-length quantity as used for SMF delta times.
    mutating func append(varLen value: Int) {
        var v = UInt32(Swift.max(0, value))
        var buffer: [UInt8] = [UInt8(v & 0x7F)]
        v >>= 7
        while v > 0 {
            buffer.insert(UInt8((v & 0x7F) | 0x80), at: 0)
            v >>= 7
        }
        append(contentsOf: buffer)
    }
}
