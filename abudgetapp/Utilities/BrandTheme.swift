import SwiftUI

enum BrandTheme {
    static let accent = Color(red: 0.99, green: 0.31, blue: 0.50)
    static let accentSecondary = Color(red: 0.37, green: 0.45, blue: 0.99)
    static let accentTertiary = Color(red: 0.15, green: 0.79, blue: 0.86)
    static let accentQuaternary = Color(red: 0.99, green: 0.58, blue: 0.33)

    static let backgroundTop = Color(red: 0.04, green: 0.07, blue: 0.16)
    static let backgroundBottom = Color(red: 0.01, green: 0.03, blue: 0.08)

    static var backgroundGradient: some View {
        LinearGradient(
            colors: [backgroundTop, backgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            RadialGradient(
                colors: [accentSecondary.opacity(0.35), .clear],
                center: .topLeading,
                startRadius: 30,
                endRadius: 400
            )
        )
        .overlay(
            RadialGradient(
                colors: [accent.opacity(0.28), .clear],
                center: .bottomTrailing,
                startRadius: 60,
                endRadius: 420
            )
        )
    }

    static func cardBackground(for colorScheme: ColorScheme) -> LinearGradient {
        let baseTop = colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.85)
        let baseBottom = colorScheme == .dark ? Color.white.opacity(0.04) : Color.white.opacity(0.70)
        return LinearGradient(
            colors: [baseTop, baseBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var cardBorder: LinearGradient {
        LinearGradient(
            colors: [accent.opacity(0.4), accentSecondary.opacity(0.35), accentTertiary.opacity(0.35)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func shadow(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.black.opacity(0.35)
            : Color.black.opacity(0.16)
    }

    static var tabBarBackground: Color {
        Color.white.opacity(0.12)
    }
}

struct BrandBackground: View {
    var body: some View {
        BrandTheme.backgroundGradient
            .ignoresSafeArea()
    }
}

struct NeonBorder: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(BrandTheme.cardBorder, lineWidth: 1.4)
                    .opacity(colorScheme == .dark ? 0.8 : 0.55)
            )
    }
}

private struct BrandCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(BrandTheme.cardBackground(for: colorScheme))
                    .shadow(color: BrandTheme.shadow(for: colorScheme).opacity(0.35), radius: 20, x: 0, y: 18)
                    .shadow(color: BrandTheme.shadow(for: colorScheme).opacity(0.1), radius: 8, x: 0, y: 4)
            )
            .modifier(NeonBorder())
    }
}

private struct BrandFormModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .formStyle(.grouped)
            .listSectionSpacing(24)
    }
}

private struct BrandFormSectionModifier: ViewModifier {
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .brandCardStyle(padding: padding)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 18, trailing: 0))
            .listRowBackground(Color.clear)
    }
}

private struct BrandFormHeaderModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(.footnote, design: .rounded).weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.8)
    }
}

struct BrandFormSection<Content: View>: View {
    private let title: String?
    private let padding: CGFloat
    private let spacing: CGFloat
    @ViewBuilder private let content: () -> Content

    init(
        _ title: String? = nil,
        padding: CGFloat = 20,
        spacing: CGFloat = 16,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.padding = padding
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: spacing) {
                if let title, !title.isEmpty {
                    Text(title)
                        .brandFormSectionHeaderStyle()
                }
                content()
            }
            .brandFormSectionStyle(padding: padding)
        }
    }
}

extension View {
    func brandCardStyle(padding: CGFloat = 22) -> some View {
        modifier(BrandCardModifier(padding: padding))
    }

    func neonBorder() -> some View {
        modifier(NeonBorder())
    }

    func brandFormStyle() -> some View {
        modifier(BrandFormModifier())
    }

    func brandFormSectionStyle(padding: CGFloat = 20) -> some View {
        modifier(BrandFormSectionModifier(padding: padding))
    }

    func brandFormSectionHeaderStyle() -> some View {
        modifier(BrandFormHeaderModifier())
    }
}
