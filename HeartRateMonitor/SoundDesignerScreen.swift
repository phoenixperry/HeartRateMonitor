//
//  SoundDesignerScreen.swift
//
//  Designer-only screen for auditioning per-player note assignments and
//  saving them as presets. Opens from Configuration → Dev Settings →
//  "Sound designer".
//
//  Workflow: open the MiniFreak plugin UI from this screen, pick a scale,
//  let auto-fill spread the scale across the six players, tap "test" on
//  each player to hear it through the plugin, tweak per-player notes by
//  hand if needed, then "Save as new" to preserve the voicing. Mark a
//  preset as default to load it on app launch.
//

import SwiftUI

struct SoundDesignerScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var manager: SoundDesignManager = .shared

    @State private var saveSheetVisible = false
    @State private var newPresetName: String = ""
    @State private var deleteConfirmVisible = false

    var body: some View {
        ZStack {
            Palette.canvas.ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    inner
                        .padding(.horizontal, 28)
                        .padding(.top, 24)
                        .padding(.bottom, 16)
                        .frame(maxWidth: .infinity)
                }
                footer
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
            }
        }
        .tint(Palette.ink)
        .preferredColorScheme(.light)
        .frame(minWidth: 760, minHeight: 620)
        .sheet(isPresented: $saveSheetVisible) {
            savePresetSheet
        }
        .alert("Delete this preset?", isPresented: $deleteConfirmVisible) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                manager.deleteActive()
            }
        } message: {
            Text("\"\(manager.active.name)\" will be removed. The built-in preset cannot be deleted.")
        }
    }

    // MARK: - Inner

    private var inner: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            presetBar
            scaleRow
            playerRows
            tuningRow
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(text: "Settings")
                Text("Sound designer")
                    .font(Type.display(28, weight: .medium))
                    .foregroundColor(Palette.ink)
                    .kerning(-0.4)
            }
            Spacer()
            Button {
                AUEngine.shared.openPluginUI()
            } label: {
                Text("Open plugin")
            }
            .buttonStyle(BWOutlineButtonStyle(minWidth: 140, height: 32))
        }
        .padding(.top, 8)
    }

    // MARK: - Preset bar

    private var presetBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: "Preset")
            HStack(spacing: 12) {
                Menu {
                    ForEach(manager.presets) { preset in
                        Button {
                            manager.setActive(preset.id)
                        } label: {
                            if preset.id == manager.defaultID {
                                Label(preset.name, systemImage: "star.fill")
                            } else {
                                Text(preset.name)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(manager.active.name)
                            .font(Type.sans(13, weight: .medium))
                            .foregroundColor(Palette.ink)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Palette.ink)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .frame(minWidth: 260, alignment: .leading)
                    .background(Palette.canvas)
                    .overlay(Rectangle().stroke(Palette.ink, lineWidth: 1))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)

                Button("Set as default") { manager.markActiveAsDefault() }
                    .buttonStyle(BWOutlineButtonStyle(minWidth: 140, height: 32))

                Button("Delete") { deleteConfirmVisible = true }
                    .buttonStyle(BWTextLinkButtonStyle())
                    .disabled(manager.active.id == SoundPreset.builtIn.id)
                    .opacity(manager.active.id == SoundPreset.builtIn.id ? 0.35 : 1)

                Spacer()
            }
            if manager.active.id == manager.defaultID {
                Text("Loads on app launch")
                    .font(Type.sans(10, weight: .medium))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundColor(Palette.muted)
            }
        }
    }

    // MARK: - Scale + root

    private var scaleRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: "Scale")

            HStack(spacing: 24) {
                // Scale dropdown
                Menu {
                    ForEach(MusicalScale.allCases) { scale in
                        Button {
                            manager.updateActive { $0.scale = scale }
                            applyAutoFillIfOn()
                            previewVoicing()
                        } label: {
                            Text(scale.displayName)
                        }
                    }
                } label: {
                    dropdownLabel(manager.active.scale.displayName, minWidth: 220)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)

                // Root note dropdown
                Menu {
                    // Common roots within ±2 octaves of middle C.
                    ForEach(36...84, id: \.self) { midi in
                        Button {
                            manager.updateActive { $0.rootMIDI = UInt8(midi) }
                            applyAutoFillIfOn()
                            previewVoicing()
                        } label: {
                            Text(MIDINoteName.label(for: UInt8(midi)))
                        }
                    }
                } label: {
                    dropdownLabel("Root: \(MIDINoteName.label(for: manager.active.rootMIDI))",
                                  minWidth: 180)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)

                Toggle("Auto-fill from scale", isOn: Binding(
                    get: { manager.active.autoFillFromScale },
                    set: { newValue in
                        manager.updateActive { $0.autoFillFromScale = newValue }
                        if newValue {
                            applyAutoFillIfOn()
                            previewVoicing()
                        }
                    }
                ))
                .toggleStyle(RadialToggleStyle())

                Spacer()
            }
        }
    }

    // MARK: - Per-player

    private var playerRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: "Players")

            VStack(spacing: 0) {
                ForEach(1...6, id: \.self) { player in
                    if player > 1 { Hairline() }
                    playerRow(player)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .background(Palette.canvas)
            .bwOutline(1)
        }
    }

    private func playerRow(_ player: Int) -> some View {
        let currentNote = manager.active.notesByPlayer[player] ?? manager.active.rootMIDI
        let pool = scalePool()
        return HStack(spacing: 14) {
            Text("Player \(player)")
                .font(Type.sans(11, weight: .medium))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundColor(Palette.ink)
                .frame(width: 80, alignment: .leading)

            Menu {
                ForEach(pool, id: \.self) { midi in
                    Button {
                        manager.updateActive { $0.notesByPlayer[player] = midi }
                        // Audition the new assignment immediately so the
                        // operator can A/B different notes by clicking around.
                        AUEngine.shared.playTestNote(midi: midi)
                    } label: {
                        Text(MIDINoteName.label(for: midi))
                    }
                }
            } label: {
                dropdownLabel(MIDINoteName.label(for: currentNote), minWidth: 160)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)

            Spacer()

            Button {
                AUEngine.shared.playTestNote(midi: currentNote)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill").font(.system(size: 10, weight: .bold))
                    Text("Test")
                }
            }
            .buttonStyle(BWOutlineButtonStyle(minWidth: 96, height: 30))
        }
    }

    // MARK: - Tuning (velocity + note duration)

    private var tuningRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: "Tuning")
            HStack(spacing: 24) {
                tuningSlider(label: "Velocity",
                             value: Double(manager.active.velocity),
                             range: 1...127,
                             format: "%.0f",
                             onChange: { v in
                                 manager.updateActive { $0.velocity = UInt8(v.rounded()) }
                             },
                             onRelease: { previewFirstPlayer() })
                tuningSlider(label: "Note duration",
                             value: manager.active.noteDuration,
                             range: 0.1...2.0,
                             format: "%.2f s",
                             onChange: { v in
                                 manager.updateActive { $0.noteDuration = v }
                             },
                             onRelease: { previewFirstPlayer() })
            }
        }
    }

    private func tuningSlider(label: String,
                              value: Double,
                              range: ClosedRange<Double>,
                              format: String,
                              onChange: @escaping (Double) -> Void,
                              onRelease: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(Type.sans(10, weight: .medium))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundColor(Palette.muted)
                Spacer()
                Text(String(format: format, value))
                    .font(Type.sans(11, weight: .medium))
                    .foregroundColor(Palette.ink)
            }
            Slider(value: Binding(get: { value }, set: { onChange($0) }),
                   in: range,
                   onEditingChanged: { editing in
                       // Fire only on release so dragging the slider doesn't
                       // spam 60+ notes per second.
                       if !editing { onRelease() }
                   })
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Save as new preset…") { newPresetName = ""; saveSheetVisible = true }
                .buttonStyle(BWOutlineButtonStyle(minWidth: 200, height: 38))
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(BWPrimaryButtonStyle(minWidth: 140, height: 38))
        }
    }

    // MARK: - Save sheet

    private var savePresetSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Save preset")
                .font(Type.display(22, weight: .medium))
                .foregroundColor(Palette.ink)
            TextField("Preset name", text: $newPresetName)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Palette.canvas)
                .overlay(Rectangle().stroke(Palette.ink, lineWidth: 1))
            HStack {
                Spacer()
                Button("Cancel") { saveSheetVisible = false }
                    .buttonStyle(BWOutlineButtonStyle(minWidth: 100, height: 34))
                Button("Save") {
                    let trimmed = newPresetName.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    manager.saveAsNew(name: trimmed)
                    saveSheetVisible = false
                }
                .buttonStyle(BWPrimaryButtonStyle(minWidth: 100, height: 34))
                .disabled(newPresetName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
        .background(Palette.canvas)
        .preferredColorScheme(.light)
    }

    // MARK: - Helpers

    private func dropdownLabel(_ text: String, minWidth: CGFloat) -> some View {
        HStack(spacing: 8) {
            Text(text)
                .font(Type.sans(12, weight: .medium))
                .foregroundColor(Palette.ink)
                .lineLimit(1)
            Spacer(minLength: 6)
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Palette.ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(minWidth: minWidth, alignment: .leading)
        .background(Palette.canvas)
        .overlay(Rectangle().stroke(Palette.ink, lineWidth: 1))
    }

    private func scalePool() -> [UInt8] {
        manager.active.scale.notes(rootMIDI: manager.active.rootMIDI)
    }

    private func applyAutoFillIfOn() {
        guard manager.active.autoFillFromScale else { return }
        manager.updateActive { preset in
            preset.notesByPlayer = SoundPreset.autoFilled(scale: preset.scale,
                                                          rootMIDI: preset.rootMIDI)
        }
    }

    /// Ascending arpeggio of all six player notes — used when a scale-wide
    /// change happens (scale switch, root switch, auto-fill toggled on) so
    /// the operator immediately hears the new voicing top to bottom.
    private func previewVoicing() {
        let notes = (1...6).compactMap { manager.active.notesByPlayer[$0] }
        let stride: TimeInterval = 0.09
        for (i, midi) in notes.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * stride) {
                AUEngine.shared.playTestNote(midi: midi)
            }
        }
    }

    /// Single P1 note — used to demonstrate the new velocity / note duration
    /// after a slider settles.
    private func previewFirstPlayer() {
        if let midi = manager.active.notesByPlayer[1] {
            AUEngine.shared.playTestNote(midi: midi)
        }
    }
}

#Preview {
    SoundDesignerScreen()
}
