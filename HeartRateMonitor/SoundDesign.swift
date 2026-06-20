//
//  SoundDesign.swift
//
//  Per-player MIDI note assignment + named presets that drive AUEngine.
//
//  The engine used to use a hardcoded notesByPlayer dictionary. Now it reads
//  from `SoundDesignManager.shared.active.notesByPlayer` so a designer screen
//  can swap voicings live while auditioning sounds with the MiniFreak plugin.
//
//  Presets live in UserDefaults as JSON. The "default" preset (marked via
//  setDefault(_:)) becomes the active preset on app launch.
//

import Foundation
import Combine

// MARK: - Scale

enum MusicalScale: String, CaseIterable, Codable, Identifiable {
    case chromatic
    case major
    case naturalMinor
    case majorPentatonic
    case minorPentatonic
    case dorian
    case phrygian
    case lydian
    case mixolydian
    case blues
    case wholeTone

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chromatic:        return "Chromatic"
        case .major:            return "Major"
        case .naturalMinor:     return "Natural minor"
        case .majorPentatonic:  return "Major pentatonic"
        case .minorPentatonic:  return "Minor pentatonic"
        case .dorian:           return "Dorian"
        case .phrygian:         return "Phrygian"
        case .lydian:           return "Lydian"
        case .mixolydian:       return "Mixolydian"
        case .blues:            return "Blues"
        case .wholeTone:        return "Whole tone"
        }
    }

    /// Semitone offsets within one octave above the root.
    var degrees: [Int] {
        switch self {
        case .chromatic:        return [0,1,2,3,4,5,6,7,8,9,10,11]
        case .major:            return [0,2,4,5,7,9,11]
        case .naturalMinor:     return [0,2,3,5,7,8,10]
        case .majorPentatonic:  return [0,2,4,7,9]
        case .minorPentatonic:  return [0,3,5,7,10]
        case .dorian:           return [0,2,3,5,7,9,10]
        case .phrygian:         return [0,1,3,5,7,8,10]
        case .lydian:           return [0,2,4,6,7,9,11]
        case .mixolydian:       return [0,2,4,5,7,9,10]
        case .blues:            return [0,3,5,6,7,10]
        case .wholeTone:        return [0,2,4,6,8,10]
        }
    }

    /// All MIDI notes in this scale across the given octave window (relative
    /// to the root's octave), sorted ascending. Used to populate per-player
    /// note pickers.
    func notes(rootMIDI: UInt8,
               minOctaveOffset: Int = -1,
               maxOctaveOffset: Int = 2) -> [UInt8] {
        var result: [Int] = []
        for octave in minOctaveOffset...maxOctaveOffset {
            for degree in degrees {
                let midi = Int(rootMIDI) + octave * 12 + degree
                if (0...127).contains(midi) {
                    result.append(midi)
                }
            }
        }
        return result.sorted().map { UInt8($0) }
    }
}

// MARK: - Note name helper

enum MIDINoteName {
    /// "C4 (60)" → human label for any MIDI value 0–127.
    static func label(for midi: UInt8) -> String {
        let names = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
        let octave = Int(midi) / 12 - 1
        let name = names[Int(midi) % 12]
        return "\(name)\(octave) (\(midi))"
    }
}

// MARK: - Preset

struct SoundPreset: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var rootMIDI: UInt8
    var scale: MusicalScale
    /// When true, changing the scale or root re-fills the per-player notes
    /// with ascending scale degrees. When false, your manual assignments
    /// stick and only the picker contents update.
    var autoFillFromScale: Bool
    var notesByPlayer: [Int: UInt8]
    var velocity: UInt8
    var noteDuration: Double

    init(id: UUID = UUID(),
         name: String,
         rootMIDI: UInt8 = 60,
         scale: MusicalScale = .majorPentatonic,
         autoFillFromScale: Bool = true,
         notesByPlayer: [Int: UInt8]? = nil,
         velocity: UInt8 = 96,
         noteDuration: Double = 0.6) {
        self.id = id
        self.name = name
        self.rootMIDI = rootMIDI
        self.scale = scale
        self.autoFillFromScale = autoFillFromScale
        self.velocity = velocity
        self.noteDuration = noteDuration
        if let n = notesByPlayer {
            self.notesByPlayer = n
        } else {
            self.notesByPlayer = Self.autoFilled(scale: scale, rootMIDI: rootMIDI)
        }
    }

    /// Six ascending notes from the scale starting at root.
    static func autoFilled(scale: MusicalScale, rootMIDI: UInt8) -> [Int: UInt8] {
        let pool = scale.notes(rootMIDI: rootMIDI, minOctaveOffset: 0, maxOctaveOffset: 3)
        var map: [Int: UInt8] = [:]
        for player in 1...6 {
            let idx = min(player - 1, pool.count - 1)
            map[player] = pool[idx]
        }
        return map
    }

    /// Ships with the app — matches the previous hardcoded C-triad.
    static let builtIn = SoundPreset(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "C triad (default)",
        rootMIDI: 60,
        scale: .major,
        autoFillFromScale: false,
        notesByPlayer: [1: 60, 2: 64, 3: 67, 4: 72, 5: 76, 6: 79]
    )
}

// MARK: - Manager

final class SoundDesignManager: ObservableObject {
    static let shared = SoundDesignManager()

    @Published var presets: [SoundPreset]
    @Published var activeID: UUID

    private let presetsKey = "SoundDesignPresets.v1"
    private let defaultKey = "SoundDesignDefaultID.v1"

    private init() {
        // Always keep the built-in as a known-good fallback, even if the
        // user has saved their own presets.
        let loaded = Self.loadPresets()
        let initialPresets: [SoundPreset]
        if loaded.isEmpty {
            initialPresets = [.builtIn]
        } else if loaded.contains(where: { $0.id == SoundPreset.builtIn.id }) {
            initialPresets = loaded
        } else {
            initialPresets = [.builtIn] + loaded
        }

        // Pick active preset: user's "default" if set and present, else first.
        let defaultIDString = UserDefaults.standard.string(forKey: defaultKey)
        let initialActive: UUID
        if let s = defaultIDString,
           let id = UUID(uuidString: s),
           initialPresets.contains(where: { $0.id == id }) {
            initialActive = id
        } else {
            initialActive = initialPresets.first?.id ?? SoundPreset.builtIn.id
        }

        self.presets = initialPresets
        self.activeID = initialActive
        persist()
    }

    var active: SoundPreset {
        presets.first(where: { $0.id == activeID }) ?? SoundPreset.builtIn
    }

    /// Apply changes to the active preset in-memory and persist.
    func updateActive(_ mutate: (inout SoundPreset) -> Void) {
        guard let idx = presets.firstIndex(where: { $0.id == activeID }) else { return }
        var p = presets[idx]
        mutate(&p)
        presets[idx] = p
        persist()
    }

    /// Switch which preset is active. Engine picks this up on next noteOn.
    func setActive(_ id: UUID) {
        guard presets.contains(where: { $0.id == id }) else { return }
        activeID = id
    }

    /// Save the active preset's current state as a brand-new preset.
    func saveAsNew(name: String) {
        var copy = active
        copy.id = UUID()
        copy.name = name
        presets.append(copy)
        activeID = copy.id
        persist()
    }

    func deleteActive() {
        guard activeID != SoundPreset.builtIn.id else { return } // never delete built-in
        presets.removeAll { $0.id == activeID }
        activeID = presets.first?.id ?? SoundPreset.builtIn.id
        persist()
    }

    /// Mark the active preset as the one that should load on app launch.
    func markActiveAsDefault() {
        UserDefaults.standard.set(activeID.uuidString, forKey: defaultKey)
    }

    var defaultID: UUID? {
        guard let s = UserDefaults.standard.string(forKey: defaultKey) else { return nil }
        return UUID(uuidString: s)
    }

    // MARK: - Persistence

    private func persist() {
        do {
            let data = try JSONEncoder().encode(presets)
            UserDefaults.standard.set(data, forKey: presetsKey)
        } catch {
            print("⚠️ SoundDesignManager: failed to persist — \(error.localizedDescription)")
        }
    }

    private static func loadPresets() -> [SoundPreset] {
        guard let data = UserDefaults.standard.data(forKey: "SoundDesignPresets.v1") else {
            return []
        }
        return (try? JSONDecoder().decode([SoundPreset].self, from: data)) ?? []
    }
}
