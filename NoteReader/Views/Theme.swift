import SwiftUI
import UIKit

extension UIColor {
    /// Parses "#RRGGBB" or "RRGGBB".
    convenience init(hex: String) {
        var value: UInt64 = 0
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = CGFloat((value >> 16) & 0xFF) / 255.0
        let g = CGFloat((value >> 8) & 0xFF) / 255.0
        let b = CGFloat(value & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}

extension Color {
    init(hex: String) {
        self.init(UIColor(hex: hex))
    }

    /// A colour that switches with the system appearance.
    static func adaptive(light: String, dark: String) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

/// Light-pink theme (deep plum in dark mode).
enum Theme {
    static let background = Color.adaptive(light: "#FCEEF2", dark: "#1E1218")
    static let card = Color.adaptive(light: "#FFF8FA", dark: "#2A1A22")
    static let cardBorder = Color.adaptive(light: "#F1CFD9", dark: "#4A2A38")
    static let segmentTrack = Color.adaptive(light: "#F6D9E1", dark: "#3A2230")
    static let ink = Color.adaptive(light: "#2A1820", dark: "#F7E8EE")
    static let secondary = Color.adaptive(light: "#74485A", dark: "#C9A3B3")
    static let accent = Color(hex: "#B8436A")
    static let accentSoft = Color.adaptive(light: "#F6D9E1", dark: "#4A2A38")
    static let correct = Color(hex: "#2F6FB0")
    static let wrong = Color(hex: "#C2410C")
    static let amber = Color(hex: "#D9930D")
    static let keyHint = Color.adaptive(light: "#DCE6F0", dark: "#2B3A4A")
    static let keyBorder = Color.adaptive(light: "#E6BACA", dark: "#5A3648")
    static let whiteKey = Color.adaptive(light: "#FFFFFF", dark: "#3A2A32")
    static let blackKey = Color.adaptive(light: "#2A1820", dark: "#0E0609")

    static let cornerRadius: CGFloat = 20

    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func noteFont(_ size: CGFloat = 24) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }
}

/// Card background used across the app.
struct CardModifier: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .fill(Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .stroke(Theme.cardBorder, lineWidth: 1)
            )
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

/// Rose button with white text.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.accent)
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// Outlined secondary button.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(Theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.cardBorder, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// Segmented control in the pink theme.
struct PillPicker<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selection = option
                    }
                } label: {
                    Text(title(option))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .foregroundColor(isSelected ? .white : Theme.ink)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isSelected ? Theme.accent : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Theme.segmentTrack)
        )
    }
}

/// Small label above a control.
struct FieldLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundColor(Theme.secondary)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum Formatting {
    static func seconds(_ ms: Int) -> String {
        String(format: "%.1f s", Double(ms) / 1000.0)
    }

    static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let whole = Int(seconds.rounded(.up))
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }
}
