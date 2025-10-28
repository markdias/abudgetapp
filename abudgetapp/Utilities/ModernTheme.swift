import SwiftUI

enum ModernTheme {
    static let primaryAccent = Color(red: 0.51, green: 0.22, blue: 0.98)
    static let secondaryAccent = Color(red: 0.21, green: 0.84, blue: 0.81)
    static let tertiaryAccent = Color(red: 0.98, green: 0.37, blue: 0.56)

    static let cardCornerRadius: CGFloat = 24
    static let elementCornerRadius: CGFloat = 18

    static func background(for colorScheme: ColorScheme) -> some View {
        let top = colorScheme == .dark
            ? Color(red: 0.05, green: 0.05, blue: 0.12)
            : Color(red: 0.92, green: 0.94, blue: 0.99)
        let bottom = colorScheme == .dark
            ? Color(red: 0.06, green: 0.09, blue: 0.21)
            : Color(red: 0.86, green: 0.91, blue: 0.99)
        return LinearGradient(
            colors: [top, bottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            RadialGradient(
                colors: [
                    primaryAccent.opacity(colorScheme == .dark ? 0.25 : 0.15),
                    .clear
                ],
                center: .top,
                startRadius: 10,
                endRadius: 420
            )
        )
    }

    static func glassBackground(for colorScheme: ColorScheme) -> some View {
        RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
            .fill(
                Color.white.opacity(colorScheme == .dark ? 0.08 : 0.25)
            )
            .background(
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .fill(Color.white.opacity(colorScheme == .dark ? 0.04 : 0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.18 : 0.25), lineWidth: 1)
            )
    }

    static func softShadow(for colorScheme: ColorScheme) -> some View {
        RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
            .fill(Color.black.opacity(colorScheme == .dark ? 0.45 : 0.18))
            .blur(radius: 24)
            .offset(y: 16)
            .opacity(0.45)
    }
}

struct ModernBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(ModernTheme.background(for: colorScheme))
    }
}

struct GlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var padding: CGFloat = 20
    var cornerRadius: CGFloat = ModernTheme.cardCornerRadius
    var blendMode: BlendMode = .plusLighter

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    ModernTheme.softShadow(for: colorScheme)
                    ModernTheme.glassBackground(for: colorScheme)
                        .blendMode(blendMode)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.18 : 0.08), lineWidth: 0.6)
            )
    }
}

extension View {
    func modernBackground() -> some View {
        modifier(ModernBackgroundModifier())
    }

    func glassCard(padding: CGFloat = 20, cornerRadius: CGFloat = ModernTheme.cardCornerRadius) -> some View {
        modifier(GlassCardModifier(padding: padding, cornerRadius: cornerRadius))
    }
}
