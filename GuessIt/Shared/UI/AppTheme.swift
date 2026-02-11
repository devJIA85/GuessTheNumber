import SwiftUI

// MARK: - Centralized Design Tokens
/// Sistema centralizado de tokens visuales para mantener consistencia en toda la app.
///
/// # Filosofía de diseño
/// - Usa Font.Design.rounded para un tono moderno y amigable
/// - Esquinas redondeadas generosas (24pt) para estética iOS 18
/// - Glassmorphism sutil con Material para profundidad
enum AppTheme {
    // MARK: - Spacing
    /// Espaciado vertical y horizontal reutilizable.
    /// - Why: mantener ritmo visual consistente en toda la UI
    enum Spacing {
        static let xSmall: CGFloat = 6
        static let small: CGFloat = 10
        static let medium: CGFloat = 16
        static let large: CGFloat = 22
        static let xLarge: CGFloat = 28
        static let xxLarge: CGFloat = 36  // Nuevo: para secciones principales
    }

    // MARK: - Corner Radius
    /// Radios de esquina para diferentes componentes.
    /// - Why: iOS 18 prefiere esquinas más generosas para look premium
    enum CornerRadius {
        static let card: CGFloat = 16        // Cards legacy
        static let glassCard: CGFloat = 24   // Nuevo: cards premium con glassmorphism
        static let field: CGFloat = 12
        static let chip: CGFloat = 10
        static let button: CGFloat = 16      // Nuevo: botones de acción
    }
    
    // MARK: - Card Padding
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
        /// Padding premium para glass cards (20pt).
        /// - Why: las glass cards necesitan más respiración visual.
        static let glass: CGFloat = 20
    }
    
    // MARK: - Typography
    /// Configuración tipográfica moderna con Font.Design.rounded.
    /// - Why: .rounded da un tono amigable pero profesional (estilo iOS 18)
    enum Typography {
        /// Título grande para secciones principales
        static func largeTitle() -> Font {
            .system(.largeTitle, design: .rounded, weight: .bold)
        }
        
        /// Título para headers de secciones
        static func title() -> Font {
            .system(.title2, design: .rounded, weight: .heavy)
        }
        
        /// Headline para subtítulos importantes
        static func headline() -> Font {
            .system(.headline, design: .rounded, weight: .semibold)
        }
        
        /// Body para contenido general
        static func body() -> Font {
            .system(.body, design: .rounded, weight: .regular)
        }
        
        /// Caption para información secundaria
        static func caption() -> Font {
            .system(.caption, design: .rounded, weight: .medium)
        }
    }
    
    // MARK: - Shadow
    /// Sombras sutiles para dar profundidad sin saturar.
    /// - Why: las sombras muy marcadas envejecen la UI
    enum Shadow {
        static let subtle = (color: Color.black.opacity(0.06), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(2))
        static let medium = (color: Color.black.opacity(0.1), radius: CGFloat(12), x: CGFloat(0), y: CGFloat(4))
    }
}

// MARK: - Semantic Colors (PALETA VIBRANTE - Game Edition)
/// Colores semánticos que se adaptan a light/dark mode.
/// - Why: centralizar colores facilita tematización y consistencia
///
/// # NUEVO: Paleta más vibrante y juguetona
/// - Más saturación en todos los colores
/// - Marcadores (GOOD/FAIR/POOR) inspirados en juegos modernos
/// - Action primary en naranja/coral vibrante (más energía que azul)
extension Color {
    // MARK: - Fallback a Assets (si existen)
    // Estos colores intentan cargar desde Assets.xcassets primero,
    // pero si no existen, usan los valores vibrantes por defecto definidos abajo.
    
    /// Fondo principal: semi-transparente para dejar ver el gradiente vibrante
    /// - Light: blanco con 85% opacidad (deja pasar el gradiente)
    /// - Dark: negro con 75% opacidad (mantiene legibilidad)
    static let appBackgroundPrimary: Color = {
        // Intentar cargar desde Assets primero
        if let assetColor = Color("BackgroundPrimary") as? Color {
            return assetColor
        }
        // Fallback: color vibrante por defecto
        return Color(.systemBackground).opacity(0.85)
    }()
    
    /// Fondo secundario: cards y superficies elevadas
    /// - Más transparencia para aprovechar el glassmorphism
    static let appBackgroundSecondary: Color = {
        if let assetColor = Color("BackgroundSecondary") as? Color {
            return assetColor
        }
        return Color(.secondarySystemBackground).opacity(0.7)
    }()
    
    /// Superficie de cards: ultra transparente para glassmorphism puro
    static let appSurfaceCard: Color = {
        if let assetColor = Color("SurfaceCard") as? Color {
            return assetColor
        }
        return Color(.tertiarySystemBackground).opacity(0.5)
    }()
    
    /// Texto principal: alto contraste para legibilidad sobre colores vibrantes
    static let appTextPrimary: Color = {
        if let assetColor = Color("TextPrimary") as? Color {
            return assetColor
        }
        return Color(.label)
    }()
    
    /// Texto secundario: contraste medio
    static let appTextSecondary: Color = {
        if let assetColor = Color("TextSecondary") as? Color {
            return assetColor
        }
        return Color(.secondaryLabel)
    }()
    
    /// Bordes sutiles: casi invisibles para look moderno
    static let appBorderSubtle: Color = {
        if let assetColor = Color("BorderSubtle") as? Color {
            return assetColor
        }
        return Color(.separator).opacity(0.2)
    }()
    
    // MARK: - Colores Vibrantes (sin Assets)
    // Estos colores NO cargan desde Assets porque queremos que sean vibrantes siempre
    
    /// Color de acción principal: NARANJA CORAL vibrante (más energía que azul)
    /// - Why: los juegos modernos usan naranjas/corales para CTAs (Duolingo, etc.)
    /// - Light: coral brillante
    /// - Dark: naranja neón
    static var appActionPrimary: Color {
        Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                // Dark mode: naranja neón vibrante
                return UIColor(red: 1.0, green: 0.45, blue: 0.20, alpha: 1.0)
            default:
                // Light mode: coral brillante
                return UIColor(red: 1.0, green: 0.35, blue: 0.30, alpha: 1.0)
            }
        })
    }
    
    /// Marcador GOOD: VERDE ESMERALDA brillante (éxito y logro)
    /// - Why: verde vibrante comunica éxito mejor que verde apagado
    /// - Inspirado en: Duolingo, Wordle
    static var appMarkGood: Color {
        Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                // Dark mode: verde neón
                return UIColor(red: 0.30, green: 0.90, blue: 0.50, alpha: 1.0)
            default:
                // Light mode: esmeralda brillante
                return UIColor(red: 0.20, green: 0.80, blue: 0.40, alpha: 1.0)
            }
        })
    }
    
    /// Marcador FAIR: AMARILLO DORADO brillante (advertencia amigable)
    /// - Why: amarillo vibrante es menos neutral que el anterior
    /// - Inspirado en: indicadores de progreso de juegos móviles
    static var appMarkFair: Color {
        Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                // Dark mode: amarillo neón
                return UIColor(red: 1.0, green: 0.85, blue: 0.20, alpha: 1.0)
            default:
                // Light mode: dorado brillante
                return UIColor(red: 1.0, green: 0.75, blue: 0.10, alpha: 1.0)
            }
        })
    }
    
    /// Marcador POOR: MAGENTA/ROSA vibrante (error juguetón, no amenazante)
    /// - Why: rojo tradicional es muy agresivo para un juego
    /// - Rosa/magenta es más amigable y mantiene la vibra juguetona
    /// - Inspirado en: Dribbble, apps de fitness gamificadas
    static var appMarkPoor: Color {
        Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                // Dark mode: magenta neón
                return UIColor(red: 1.0, green: 0.30, blue: 0.70, alpha: 1.0)
            default:
                // Light mode: rosa fucsia brillante
                return UIColor(red: 0.95, green: 0.25, blue: 0.60, alpha: 1.0)
            }
        })
    }
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
///
/// # NUEVO: Opacidad aumentada para paleta vibrante
/// - Antes: 0.12-0.15 (muy sutil, colores apagados)
/// - Después: 0.20-0.25 (más saturación, colores vibrantes brillan)
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
                    // CAMBIO: Opacidad aumentada para que los colores vibrantes se vean
                    .fill(color.opacity(isCompact ? 0.20 : 0.25))
            )
    }
}

// MARK: - Glass Card Style (DRY Principle + iOS 18 Liquid Glass)
/// ViewModifier que aplica efecto glassmorphism moderno a cualquier vista.
///
/// # Características
/// - iOS 18+: Usa Liquid Glass (.glassEffect) para efecto premium nativo
/// - iOS 13-17: Fallback a Material.regular/ultraThin con sombras
/// - Esquinas redondeadas generosas (24pt) estilo iOS 18
/// - Borde sutil para definir límites
/// - Compatible desde iOS 13+ con degradación elegante
///
/// # Por qué existe (DRY)
/// - Evita repetir el mismo código de estilo en cada sección
/// - Centraliza la estética glassmorphism en un solo lugar
/// - Facilita cambios globales de diseño
/// - Adopta automáticamente Liquid Glass en iOS 18+ sin código duplicado
///
/// # Cuándo usar
/// - Secciones principales: Input, Historial, Tablero
/// - Cualquier contenedor que necesite destacar sobre el fondo con gradiente
struct GlassCardStyle: ViewModifier {
    /// Variante del material (regular para cards principales, ultraThin para secundarias)
    let material: Material
    
    /// Padding interno de la card
    let padding: CGFloat
    
    /// Habilitar Liquid Glass en iOS 26+ (default: true)
    /// - Why: permite deshabilitar Liquid Glass si se necesita Material explícitamente
    let useLiquidGlass: Bool
    
    /// Hacer el efecto interactivo (responde a touch/pointer)
    /// - Why: Apple recomienda .interactive() para elementos táctiles
    let isInteractive: Bool
    
    /// Color de tint para dar énfasis (opcional)
    /// - Why: Apple permite usar .tint() para destacar secciones importantes
    let tintColor: Color?
    
    init(
        material: Material = .regular,
        padding: CGFloat = AppTheme.CardPadding.glass,
        useLiquidGlass: Bool = true,
        isInteractive: Bool = false,
        tintColor: Color? = nil
    ) {
        self.material = material
        self.padding = padding
        self.useLiquidGlass = useLiquidGlass
        self.isInteractive = isInteractive
        self.tintColor = tintColor
    }
    
    func body(content: Content) -> some View {
        // ESTRATEGIA: Detección de iOS 26+ para usar Liquid Glass
        // - iOS 26+: .glassEffect() proporciona Liquid Glass nativo con reflexiones y profundidad 3D
        // - iOS 13-25: Material + sombras manuales para simular glassmorphism
        // - Ambos se ven bien, pero Liquid Glass es superior en iOS 26+
        
        if #available(iOS 26.0, *), useLiquidGlass {
            // iOS 26+: LIQUID GLASS (efecto premium)
            // - Why: Apple recomienda usar .glassEffect() en custom views para iOS 26+
            // - Proporciona reflexiones, profundidad 3D, y reacciona a interacciones
            // - Se integra perfectamente con el sistema de diseño de iOS 26
            content
                .padding(padding)
                .glassEffect(
                    configureGlass(),  // Configura Glass con interactive y tint según parámetros
                    in: RoundedRectangle(
                        cornerRadius: AppTheme.CornerRadius.glassCard,
                        style: .continuous
                    )
                )
                // Nota: Liquid Glass incluye bordes y sombras automáticamente
                // por lo que no necesitamos agregarlos manualmente
        } else {
            // iOS 13-25: MATERIAL FALLBACK (glassmorphism clásico)
            // - Why: Material existe desde iOS 13 y proporciona blur + vibrancy
            // - Agregamos borde y sombra manualmente para simular el look moderno
            content
                .padding(padding)
                .background(
                    material,
                    in: RoundedRectangle(
                        cornerRadius: AppTheme.CornerRadius.glassCard,
                        style: .continuous
                    )
                )
                .overlay {
                    // Borde sutil para definir límites de la card
                    RoundedRectangle(
                        cornerRadius: AppTheme.CornerRadius.glassCard,
                        style: .continuous
                    )
                    .strokeBorder(Color.appBorderSubtle.opacity(0.3), lineWidth: 1)
                }
                .shadow(
                    color: AppTheme.Shadow.subtle.color,
                    radius: AppTheme.Shadow.subtle.radius,
                    x: AppTheme.Shadow.subtle.x,
                    y: AppTheme.Shadow.subtle.y
                )
        }
    }
    
    /// Configura el objeto Glass con interactividad y tint según parámetros.
    /// - Why: Apple permite encadenar .interactive() y .tint() para personalizar el efecto
    @available(iOS 26.0, *)
    private func configureGlass() -> Glass {
        var glass: Glass = .regular
        
        // Agregar interactividad si está habilitado
        // - Why: .interactive() hace que el efecto responda a touch y pointer en tiempo real
        if isInteractive {
            glass = glass.interactive()
        }
        
        // Agregar tint si está especificado
        // - Why: .tint() da énfasis visual a secciones importantes
        if let tintColor {
            glass = glass.tint(tintColor)
        }
        
        return glass
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
    
    /// Aplica estilo glassmorphism premium a la vista con soporte Liquid Glass.
    ///
    /// # Comportamiento adaptivo
    /// - iOS 26+: Usa Liquid Glass (.glassEffect) con soporte para interactividad y tint
    /// - iOS 13-25: Usa Material con fallback elegante
    ///
    /// # Características iOS 26+
    /// - `.interactive()`: Hace que el efecto responda a touch/pointer en tiempo real
    /// - `.tint()`: Agrega color de énfasis para destacar secciones importantes
    ///
    /// - Parameters:
    ///   - material: Material a usar en iOS 13-25 fallback (default: .regular)
    ///   - padding: Padding interno (default: CardPadding.glass)
    ///   - useLiquidGlass: Habilitar Liquid Glass en iOS 26+ (default: true)
    ///   - isInteractive: Hacer el efecto interactivo (iOS 26+) (default: false)
    ///   - tintColor: Color de tint para énfasis (iOS 26+) (default: nil)
    /// - Returns: Vista con efecto glass aplicado
    func glassCard(
        material: Material = .regular,
        padding: CGFloat = AppTheme.CardPadding.glass,
        useLiquidGlass: Bool = true,
        isInteractive: Bool = false,
        tintColor: Color? = nil
    ) -> some View {
        modifier(GlassCardStyle(
            material: material,
            padding: padding,
            useLiquidGlass: useLiquidGlass,
            isInteractive: isInteractive,
            tintColor: tintColor
        ))
    }
}
// MARK: - Modern Button Styles (SwiftUI 2025 Liquid Glass Support)
/// Helper para aplicar estilos de botón modernos con soporte Liquid Glass.
///
/// # Por qué existe
/// - Centraliza la lógica de detección de iOS 26+
/// - Proporciona fallback elegante a .borderedProminent
/// - Permite usar Liquid Glass button styles sin #available en cada uso
///
/// # SwiftUI 2025 Update
/// - Usa el nuevo `.glass` button style introducido en June 2025
/// - `.glass` es el reemplazo oficial de `.glassProminent` para Liquid Glass
extension View {
    /// Aplica un button style prominent con soporte Liquid Glass.
    ///
    /// # Comportamiento
    /// - iOS 26+: Usa .glass (Liquid Glass nativo - SwiftUI 2025)
    /// - iOS 13-25: Usa .borderedProminent (style clásico)
    ///
    /// # Cuándo usar
    /// - Botones de acción primaria (CTA)
    /// - Botones que necesitan máxima prominencia visual
    ///
    /// # SwiftUI 2025
    /// - Usa buttonStyle(.glass) como recomienda Apple en June 2025 updates
    ///
    /// - Returns: Vista con button style aplicado
    func modernProminentButton() -> some View {
        if #available(iOS 26.0, *) {
            // iOS 26+: Liquid Glass button (SwiftUI 2025)
            // - Why: .glass es el button style oficial para Liquid Glass
            // - Proporciona reflexiones, profundidad 3D, y responde a interacciones
            return AnyView(self.buttonStyle(.glass))
        } else {
            // iOS 13-25: Bordered prominent fallback
            // - Why: .borderedProminent existe desde iOS 15, se ve bien
            return AnyView(self.buttonStyle(.borderedProminent))
        }
    }
}

// MARK: - Premium Background Gradient (VERSIÓN VIBRANTE - Game Edition)
/// Fondo con gradiente vibrante y juguetón perfecto para un juego.
///
/// # Diseño NUEVO
/// - Gradiente colorido con tonos púrpura/azul/rosa vibrantes
/// - Inspirado en juegos modernos (Wordle, Duolingo, Alto's Adventure)
/// - Más saturación para dar energía y personalidad
/// - Compatible con light/dark mode (se adapta automáticamente)
///
/// # Por qué cambió
/// - La versión anterior era demasiado sobria para un juego
/// - Los juegos necesitan paletas que transmitan diversión y energía
/// - El color ayuda a crear engagement emocional
///
/// # Cuándo usar
/// - Como fondo de pantallas principales (GameView, HistoryView)
/// - Cualquier vista que necesite personalidad vibrante
struct PremiumBackgroundGradient: View {
    /// Color scheme del entorno (light/dark)
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        // Gradiente vibrante con múltiples stops que crean profundidad cromática
        // Why: los gradientes coloridos con 5+ stops crean transiciones orgánicas
        LinearGradient(
            gradient: Gradient(stops: [
                // Top: púrpura vibrante (energía y creatividad)
                .init(color: topColor, location: 0.0),
                .init(color: middleTopColor, location: 0.3),
                
                // Middle: azul brillante (confianza y claridad)
                .init(color: middleColor, location: 0.5),
                
                // Bottom: cyan/teal (frescura y modernidad)
                .init(color: middleBottomColor, location: 0.7),
                .init(color: bottomColor, location: 1.0)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Vibrant Adaptive Colors
    /// Colores vibrantes que se adaptan a light/dark mode.
    /// - Why: el gradiente debe tener punch visual pero sin cegar al usuario
    
    private var topColor: Color {
        colorScheme == .dark
            ? Color(red: 0.35, green: 0.15, blue: 0.55)  // Púrpura intenso oscuro
            : Color(red: 0.75, green: 0.50, blue: 0.90)  // Púrpura brillante suave
    }
    
    private var middleTopColor: Color {
        colorScheme == .dark
            ? Color(red: 0.30, green: 0.25, blue: 0.65)  // Púrpura-azul profundo
            : Color(red: 0.70, green: 0.60, blue: 0.95)  // Lavanda vibrante
    }
    
    private var middleColor: Color {
        colorScheme == .dark
            ? Color(red: 0.20, green: 0.35, blue: 0.70)  // Azul real vibrante
            : Color(red: 0.55, green: 0.70, blue: 0.98)  // Azul cielo brillante
    }
    
    private var middleBottomColor: Color {
        colorScheme == .dark
            ? Color(red: 0.15, green: 0.45, blue: 0.75)  // Azul cyan eléctrico
            : Color(red: 0.45, green: 0.80, blue: 0.98)  // Cyan fresco
    }
    
    private var bottomColor: Color {
        colorScheme == .dark
            ? Color(red: 0.10, green: 0.50, blue: 0.70)  // Teal profundo
            : Color(red: 0.40, green: 0.85, blue: 0.95)  // Aqua luminoso
    }
}

// MARK: - SwiftUI 2025: Background Extension Effect
/// Extiende y blur el background alrededor de los bordes con safe areas disponibles.
///
/// # SwiftUI 2025 Feature
/// - Introducido en June 2025: backgroundExtensionEffect()
/// - Duplica, refleja y blur las vistas colocadas alrededor de bordes con safe areas
/// - Crea una estética más inmersiva y moderna
///
/// # Por qué existe
/// - Elimina los bordes duros cuando hay safe areas (notch, Dynamic Island, etc.)
/// - Da sensación de continuidad visual en toda la pantalla
/// - Se integra perfectamente con Liquid Glass y gradientes premium
///
/// # Cuándo usar
/// - Pantallas con gradientes de fondo (GameView, HistoryView)
/// - Vistas que usan PremiumBackgroundGradient
/// - Cualquier vista que quiera maximizar el uso del espacio visual
extension View {
    /// Aplica background extension effect en iOS 26+.
    ///
    /// # Comportamiento
    /// - iOS 26+: Usa backgroundExtensionEffect() para blur y extend en bordes
    /// - iOS 13-25: No hace nada (retorna la vista sin cambios)
    ///
    /// # Por qué condicional
    /// - backgroundExtensionEffect() solo existe en iOS 26+
    /// - El fallback es seguro: la vista se ve bien sin este efecto
    ///
    /// - Returns: Vista con background extension aplicado (iOS 26+) o sin cambios
    func modernBackgroundExtension() -> some View {
        if #available(iOS 26.0, *) {
            // iOS 26+: Background extension effect
            // - Why: crea continuidad visual en bordes con safe areas
            // - Duplica, refleja y blur automáticamente
            return AnyView(self.backgroundExtensionEffect())
        } else {
            // iOS 13-25: No hay efecto, retornar vista sin cambios
            return AnyView(self)
        }
    }
}

