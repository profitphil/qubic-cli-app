import SwiftUI

/// Qubic brand palette + reusable styling.
enum Theme {
    /// Mint-cyan accent (matches QX Dashboard button). Slightly softer than #23FFFF.
    static let accent = Color(red: 0x7F/255, green: 0xEE/255, blue: 0xDB/255)

    /// Deep near-black with a blue undertone — matches the QX Dashboard bg.
    static let base = Color(red: 0x0B/255, green: 0x11/255, blue: 0x17/255)

    /// Barely-lifted card surface.
    static let surface = Color(red: 0x11/255, green: 0x19/255, blue: 0x21/255)

    /// Pressed / hover card surface.
    static let surfaceHigh = Color(red: 0x1A/255, green: 0x24/255, blue: 0x2D/255)

    /// Subtle hairline on dark bg (matches the faint card border on QX Dashboard).
    static let hairline = Color.white.opacity(0.06)

    /// Primary text on dark.
    static let text = Color.white.opacity(0.92)
    static let textDim = Color.white.opacity(0.55)
    static let textFaint = Color.white.opacity(0.35)

    /// Semantic
    static let success = Color(red: 0.30, green: 0.95, blue: 0.60)
    static let warn    = Color(red: 1.00, green: 0.75, blue: 0.30)
    static let danger  = Color(red: 1.00, green: 0.45, blue: 0.45)

    /// Hero gradient — deep base with a hint of teal wash for headers.
    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [base, surface, accent.opacity(0.10)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Accent-filled soft gradient for CTAs.
    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accent.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - View helpers

/// Card container with surface bg, rounded corners, hairline border.
struct QCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
    }
}

/// Primary action button — cyan background on dark.
struct QPrimaryButtonStyle: ButtonStyle {
    var disabled: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Theme.base)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(disabled ? AnyShapeStyle(Theme.surfaceHigh) : AnyShapeStyle(Theme.accentGradient))
            )
            .foregroundStyle(disabled ? Theme.textDim : Theme.base)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Ghost / secondary button — cyan outline on dark.
struct QGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Theme.accent.opacity(0.5), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Pill badge.
struct QBadge: View {
    let text: String
    var color: Color = Theme.accent
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(0.6)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

/// Small cyan dot for selected/active states.
struct QDot: View {
    var on: Bool
    var body: some View {
        Circle()
            .fill(on ? Theme.accent : Theme.hairline)
            .frame(width: 6, height: 6)
    }
}

// MARK: - Modifiers

extension View {
    /// Set this screen's background to the Theme.base with safe-area fill.
    func qubicBackground() -> some View {
        self.background(Theme.base.ignoresSafeArea())
    }

    /// Apply standard list-row appearance in the dark theme.
    func qubicListRow() -> some View {
        self
            .listRowBackground(Color.clear)
            .listRowSeparatorTint(Theme.hairline)
    }
}

// MARK: - Global appearance

enum QubicAppearance {
    /// Call once on app launch to tint UIKit-backed controls (NavBar, TabBar).
    static func apply() {
        let accent = UIColor(Theme.accent)
        let base   = UIColor(Theme.base)
        let text   = UIColor(Theme.text)

        // Nav bar
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = base
        nav.titleTextAttributes = [
            .foregroundColor: text,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        nav.largeTitleTextAttributes = [
            .foregroundColor: text,
            .font: UIFont.systemFont(ofSize: 32, weight: .bold)
        ]
        nav.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = accent

        // Tab bar
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = base
        tab.shadowColor = UIColor(Theme.hairline)
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
        UITabBar.appearance().tintColor = accent
        UITabBar.appearance().unselectedItemTintColor = UIColor(Theme.textDim)
    }
}
