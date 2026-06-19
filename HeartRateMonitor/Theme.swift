import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Palette
// Pure black and white minimalism. canvas = surface, ink = foreground.
// All transparencies are pure black so the palette stays strictly monochrome.
enum Palette {
    static let canvas = Color.white
    static let ink    = Color.black
    static let line   = Color.black.opacity(0.18)   // hairline rules + dividers
    static let muted  = Color.black.opacity(0.50)   // secondary copy
    static let faint  = Color.black.opacity(0.05)   // very subtle wash (rare)
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Typography
// Space Grotesk for display / numerics, DM Sans for body / UI labels.
// Font.custom silently falls back to the system font if the postscript name
// isn't registered yet, so the app keeps working before the fonts are added.
enum Typeface {
    static let displayRegular = "SpaceGrotesk-Regular"
    static let displayMedium  = "SpaceGrotesk-Medium"
    static let displayBold    = "SpaceGrotesk-Bold"
    static let sansRegular    = "DMSans-Regular"
    static let sansMedium     = "DMSans-Medium"
    static let sansBold       = "DMSans-Bold"
}

enum Type {
    static func display(_ size: CGFloat, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
        let name = (weight == .bold) ? Typeface.displayBold
                : (weight == .medium) ? Typeface.displayMedium
                : Typeface.displayRegular
        return .custom(name, size: size)
    }
    static func sans(_ size: CGFloat, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
        let name = (weight == .bold) ? Typeface.sansBold
                : (weight == .medium) ? Typeface.sansMedium
                : Typeface.sansRegular
        return .custom(name, size: size)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Buttons
// Primary: solid black, white type, square corners.
// Secondary: white fill, 1pt black outline, square corners.

struct BWPrimaryButtonStyle: ButtonStyle {
    var minWidth: CGFloat = 200
    var height: CGFloat = 48

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Type.sans(12, weight: .medium))
            .tracking(2.5)
            .textCase(.uppercase)
            .foregroundColor(.white)
            .frame(minWidth: minWidth, minHeight: height)
            .padding(.horizontal, 24)
            .background(Palette.ink)
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct BWOutlineButtonStyle: ButtonStyle {
    var minWidth: CGFloat = 120
    var height: CGFloat = 38

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Type.sans(11, weight: .medium))
            .tracking(2)
            .textCase(.uppercase)
            .foregroundColor(Palette.ink)
            .frame(minWidth: minWidth, minHeight: height)
            .padding(.horizontal, 16)
            .background(Palette.canvas)
            .overlay(Rectangle().stroke(Palette.ink, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.55 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Tertiary tiny text link button — for low-priority controls (Disconnect, etc).
struct BWTextLinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Type.sans(10, weight: .medium))
            .tracking(1.6)
            .textCase(.uppercase)
            .foregroundColor(Palette.muted)
            .opacity(configuration.isPressed ? 0.4 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - View helpers

extension View {
    /// Square hairline outline (1pt by default).
    func bwOutline(_ width: CGFloat = 1, color: Color = Palette.ink) -> some View {
        overlay(Rectangle().stroke(color, lineWidth: width))
    }

    /// Gentle fade-in for primary content as it enters a screen.
    func bwFadeIn(delay: Double = 0) -> some View {
        modifier(BWFadeIn(delay: delay))
    }
}

struct BWFadeIn: ViewModifier {
    var delay: Double
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .animation(.easeOut(duration: 0.6).delay(delay), value: shown)
            .onAppear { shown = true }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Small atoms used across screens

/// A horizontal hairline rule. Use to delineate sections without using full borders.
struct Hairline: View {
    var color: Color = Palette.line
    var height: CGFloat = 1
    var body: some View {
        Rectangle().fill(color).frame(height: height)
    }
}

/// A small uppercase label, DM Sans medium, tracked.
struct Eyebrow: View {
    let text: String
    var color: Color = Palette.muted
    var body: some View {
        Text(text)
            .font(Type.sans(10, weight: .medium))
            .tracking(2.2)
            .textCase(.uppercase)
            .foregroundColor(color)
    }
}

/// In-page section heading. Stronger than `Eyebrow`. Used for "Discovered devices",
/// "Player assignments", "Development settings", etc.
struct SectionHeading: View {
    let title: String
    var detail: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(Type.sans(11, weight: .bold))
                .tracking(2.6)
                .textCase(.uppercase)
                .foregroundColor(Palette.ink)
            if let detail {
                Text(detail)
                    .font(Type.sans(10, weight: .medium))
                    .tracking(1.6)
                    .textCase(.uppercase)
                    .foregroundColor(Palette.muted)
            }
        }
    }
}

/// Toggle style: outlined ink circle with a filled dot inside when on.
/// Same visual language as the validation indicator — minimal radial mark.
struct RadialToggleStyle: ToggleStyle {
    var ring: CGFloat = 14
    var dot: CGFloat = 7

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            Button {
                configuration.isOn.toggle()
            } label: {
                ZStack {
                    Circle()
                        .stroke(Palette.ink, lineWidth: 1)
                        .frame(width: ring, height: ring)
                    if configuration.isOn {
                        Circle()
                            .fill(Palette.ink)
                            .frame(width: dot, height: dot)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            configuration.label
                .font(Type.sans(13))
                .foregroundColor(Palette.ink)
        }
    }
}

/// A small outlined chip used inline for status text.
struct InfoChip: View {
    let text: String
    var emphasis: Bool = false   // true = ink fill / white text, false = white fill / ink text
    var body: some View {
        Text(text.uppercased())
            .font(Type.sans(9, weight: .medium))
            .tracking(1.6)
            .foregroundColor(emphasis ? Palette.canvas : Palette.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(emphasis ? Palette.ink : Palette.canvas)
            .overlay(Rectangle().stroke(Palette.ink, lineWidth: 1))
    }
}
