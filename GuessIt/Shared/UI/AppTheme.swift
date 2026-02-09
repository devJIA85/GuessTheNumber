import SwiftUI

// Centralized tokens for the app visual system.
enum AppTheme {
    enum Spacing {
        static let xSmall: CGFloat = 6
        static let small: CGFloat = 10
        static let medium: CGFloat = 16
        static let large: CGFloat = 22
        static let xLarge: CGFloat = 28
    }

    enum CornerRadius {
        static let card: CGFloat = 16
        static let field: CGFloat = 12
        static let chip: CGFloat = 10
    }
    
    /// Variantes de padding para cards según jerarquía visual.
    enum CardPadding {
        /// Padding estándar para cards principales (16pt).
        static let standard: CGFloat = 16
        /// Padding compacto para cards secundarias (12pt).
        /// - Why: reduce densidad visual en secciones de apoyo.
        static let compact: CGFloat = 12
        /// Padding ligero para cards de menor jerarquía (10pt).
        /// - Why: hace que la card sea más liviana visualmente.
        static let light: CGFloat = 10
    }
}

extension Color {
    static let appBackgroundPrimary = Color("BackgroundPrimary")
    static let appBackgroundSecondary = Color("BackgroundSecondary")
    static let appSurfaceCard = Color("SurfaceCard")
    static let appTextPrimary = Color("TextPrimary")
    static let appTextSecondary = Color("TextSecondary")
    static let appBorderSubtle = Color("BorderSubtle")
    static let appActionPrimary = Color("ActionPrimary")
    static let appMarkGood = Color("MarkGood")
    static let appMarkFair = Color("MarkFair")
    static let appMarkPoor = Color("MarkPoor")
}

/// Card estándar con jerarquía visual configurable.
///
/// # Variantes
/// - `.standard`: card principal con padding completo (16pt).
/// - `.compact`: card secundaria con padding reducido (12pt).
/// - `.light`: card liviana con padding mínimo (10pt).
///
/// # Por qué existen variantes
/// - Permite establecer jerarquía visual sin duplicar código.
/// - Cards secundarias (Estado, Intentos) deben ser más livianas que el input principal.
struct AppCard<Content: View>: View {
    enum Style {
        case standard
        case compact
        case light
        
        var padding: CGFloat {
            switch self {
            case .standard: return AppTheme.CardPadding.standard
            case .compact: return AppTheme.CardPadding.compact
            case .light: return AppTheme.CardPadding.light
            }
        }
        
        /// Título más discreto en variantes light/compact.
        var titleFont: Font {
            switch self {
            case .standard: return .subheadline
            case .compact, .light: return .caption
            }
        }
    }
    
    private let title: String?
    private let style: Style
    private let content: Content

    init(
        title: String? = nil,
        style: Style = .standard,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.style = style
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            if let title {
                Text(title)
                    .font(style.titleFont)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.appTextSecondary)
            }

            content
        }
        .padding(style.padding)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
                .fill(Color.appSurfaceCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
                .strokeBorder(Color.appBorderSubtle, lineWidth: 1)
        )
    }
}

struct AppTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(AppTheme.Spacing.small)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.field, style: .continuous)
                    .fill(Color.appBackgroundSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.field, style: .continuous)
                    .strokeBorder(Color.appBorderSubtle, lineWidth: 1)
            )
    }
}

/// Estilo de chip/badge compacto para métricas (GOOD/FAIR/POOR).
///
/// # Por qué existe
/// - Evita duplicar código de chips en AttemptRowView y otras vistas.
/// - Centraliza el diseño de badges para mantener consistencia.
struct MetricChipStyle: ViewModifier {
    let color: Color
    let isCompact: Bool
    
    func body(content: Content) -> some View {
        content
            .font(isCompact ? .system(size: 10, weight: .medium) : .caption)
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, isCompact ? 6 : 8)
            .padding(.vertical, isCompact ? 3 : 4)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.chip, style: .continuous)
                    .fill(color.opacity(isCompact ? 0.12 : 0.15))
            )
    }
}

extension View {
    func appTextFieldStyle() -> some View {
        modifier(AppTextFieldStyle())
    }
    
    /// Aplica estilo de chip/badge para métricas.
    /// - Parameters:
    ///   - color: color semántico (appMarkGood, appMarkFair, appMarkPoor).
    ///   - compact: si true, usa tamaño más pequeño para densidad reducida.
    func metricChip(color: Color, compact: Bool = false) -> some View {
        modifier(MetricChipStyle(color: color, isCompact: compact))
    }
}
