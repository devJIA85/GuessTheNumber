import SwiftUI
import Observation

// MARK: - Victory Splash State

@Observable
final class VictorySplashState {
    var isPresented: Bool = false
    var didFireHaptic: Bool = false

    // Marca la splash como visible.
    // Por qué: centraliza el estado y evita duplicar lógica en la vista.
    func present() {
        isPresented = true
    }

    // Oculta la splash cuando la partida cambia o el usuario inicia otra.
    func dismiss() {
        isPresented = false
    }

    // Evita repetir el haptic varias veces para la misma victoria.
    func markHapticFired() {
        didFireHaptic = true
    }

    // Resetea el haptic al salir del estado WON.
    func resetHaptic() {
        didFireHaptic = false
    }
}

// MARK: - Victory Splash View (Experiencia Inmersiva)

/// Pantalla de victoria fullscreen con "Game Juice" máximo.
///
/// # Arquitectura visual (ZStack)
/// 1. Fondo oscuro 85% + gradiente ambiental rotatorio
/// 2. Sistema de confeti nativo (Canvas + TimelineView)
/// 3. Contenido: rango gamificado + número secreto hero + CTA pill
///
/// # Animaciones staggered
/// Los elementos entran en secuencia (fondo → confeti → rango → secreto → métricas → botón)
/// para crear anticipación y recompensa.
struct VictorySplashView: View {
    let secret: String
    let attempts: Int
    let onNewGame: () -> Void

    // MARK: - Staggered Animation State

    @State private var showBackground = false
    @State private var showConfetti = false
    @State private var showRank = false
    @State private var showSecret = false
    @State private var showMetrics = false
    @State private var showButton = false
    @State private var shimmerOffset: CGFloat = -200

    // MARK: - Body

    var body: some View {
        ZStack {
            // CAPA 1: Fondo oscuro + gradiente ambiental
            backdrop

            // CAPA 2: Confeti (partículas nativas con Canvas)
            if showConfetti {
                ConfettiCanvasView(rankColor: rank.color)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            // CAPA 3: Contenido principal
            VStack(spacing: 32) {
                Spacer()

                // Rango gamificado con emoji
                rankSection

                // Número secreto HERO con shimmer
                secretHeroSection

                // Métricas
                metricsSection

                Spacer()

                // CTA pill "Nueva partida" con glow
                ctaButton

                Spacer()
                    .frame(height: 20)
            }
            .padding(.horizontal, 32)
        }
        .ignoresSafeArea()
        .accessibilityAddTraits(.isModal)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Victoria. \(rank.title) Secreto: \(secret). Intentos: \(attempts).")
        .onAppear {
            triggerStaggeredAnimations()
        }
    }

    // MARK: - Rango Gamificado

    /// Determina el rango del jugador basado en la cantidad de intentos.
    ///
    /// # Jerarquía
    /// - 1 intento: Mítico (neón cyan) — prácticamente imposible
    /// - 2-19 intentos: Oro (dorado) — rendimiento excepcional
    /// - 20-30 intentos: Plata (plateado) — muy bueno
    /// - 31+ intentos: Bronce (bronce cálido) — bien hecho
    private var rank: (title: String, color: Color, emoji: String) {
        switch attempts {
        case 1:
            return ("¡IMPOSIBLE!", Color.cyan, "⚡")
        case 2...19:
            return ("¡GENIO!", Color(red: 1.0, green: 0.84, blue: 0.0), "🏆")
        case 20...30:
            return ("¡EXCELENTE!", Color(red: 0.75, green: 0.75, blue: 0.80), "🥈")
        default:
            return ("¡BIEN HECHO!", Color(red: 0.80, green: 0.50, blue: 0.20), "🥉")
        }
    }

    // MARK: - Subviews

    /// Backdrop: fondo oscuro 85% + gradiente ambiental rotatorio.
    private var backdrop: some View {
        ZStack {
            Color.black.opacity(showBackground ? 0.85 : 0)
                .ignoresSafeArea()

            if showBackground {
                AmbientGradientLoop(color: rank.color)
                    .ignoresSafeArea()
            }
        }
    }

    /// Rango del jugador con emoji y tipografía hero.
    private var rankSection: some View {
        VStack(spacing: 8) {
            Text(rank.emoji)
                .font(.system(size: 56))

            Text(rank.title)
                .font(.system(.largeTitle, design: .rounded, weight: .black))
                .foregroundStyle(rank.color)
                .shadow(color: rank.color.opacity(0.5), radius: 12)
        }
        .scaleEffect(showRank ? 1.0 : 0.3)
        .opacity(showRank ? 1.0 : 0.0)
    }

    /// Número secreto gigante con efecto shimmer.
    private var secretHeroSection: some View {
        ZStack {
            // Texto base
            Text(secret)
                .font(.system(size: 64, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white)

            // Shimmer overlay: gradiente que pasa de izquierda a derecha
            Text(secret)
                .font(.system(size: 64, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.clear)
                .overlay {
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.6),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 80)
                    .offset(x: shimmerOffset)
                    .blur(radius: 4)
                }
                .mask {
                    Text(secret)
                        .font(.system(size: 64, weight: .bold, design: .monospaced))
                }
        }
        .scaleEffect(showSecret ? 1.0 : 0.8)
        .opacity(showSecret ? 1.0 : 0.0)
    }

    /// Métricas secundarias (intentos + subtítulo).
    private var metricsSection: some View {
        VStack(spacing: 6) {
            Text("\(attempts) \(attempts == 1 ? "intento" : "intentos")")
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.8))

            Text("Excelente lectura del feedback")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.5))
        }
        .opacity(showMetrics ? 1.0 : 0.0)
        .offset(y: showMetrics ? 0 : 10)
    }

    /// Botón "Nueva partida" en forma de pill con glow difuso.
    private var ctaButton: some View {
        Button(action: onNewGame) {
            Label("Nueva partida", systemImage: "plus.circle.fill")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.black)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(Capsule().fill(Color.white))
                .shadow(color: Color.white.opacity(0.4), radius: 16, y: 4)
        }
        .opacity(showButton ? 1.0 : 0.0)
        .scaleEffect(showButton ? 1.0 : 0.9)
    }

    // MARK: - Staggered Animations

    /// Dispara animaciones en secuencia para crear efecto cinematográfico.
    ///
    /// # Timing
    /// - t=0.0s: Fondo oscuro fade in
    /// - t=0.2s: Confeti empieza a caer
    /// - t=0.3s: Rango aparece con bounce (spring)
    /// - t=0.6s: Número secreto scale in
    /// - t=0.8s: Métricas fade in
    /// - t=1.0s: Botón CTA aparece
    /// - t=0.6s: Shimmer empieza a loopear
    private func triggerStaggeredAnimations() {
        // Fondo
        withAnimation(.easeOut(duration: 0.4)) {
            showBackground = true
        }

        // Confeti
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            showConfetti = true
        }

        // Rango con bounce
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                showRank = true
            }
        }

        // Número secreto
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showSecret = true
            }
        }

        // Shimmer loop
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: false)) {
                shimmerOffset = 200
            }
        }

        // Métricas
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.3)) {
                showMetrics = true
            }
        }

        // Botón CTA
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showButton = true
            }
        }
    }
}

// MARK: - Ambient Gradient Loop

/// Gradiente angular que rota lentamente para dar vida al fondo.
///
/// # Diseño
/// - Usa `AngularGradient` con el color del rango + negro
/// - Rota continuamente con animación lineal de 8 segundos
/// - Opacity ~0.3 + blur ~60 para efecto ambiental sutil
/// - No distrae del contenido principal
private struct AmbientGradientLoop: View {
    let color: Color

    @State private var angle: Double = 0

    var body: some View {
        AngularGradient(
            colors: [
                color.opacity(0.4),
                color.opacity(0.1),
                Color.purple.opacity(0.2),
                color.opacity(0.3),
                color.opacity(0.1)
            ],
            center: .center,
            angle: .degrees(angle)
        )
        .blur(radius: 60)
        .opacity(0.3)
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                angle = 360
            }
        }
    }
}

// MARK: - Confetti Canvas View

/// Sistema de confeti nativo usando Canvas + TimelineView.
///
/// # Implementación
/// - ~50 partículas generadas al aparecer
/// - Físicas simuladas: gravedad + deriva lateral + rotación
/// - Canvas renderiza rectángulos coloreados rotados (simula papel confeti)
/// - Colores: mezcla de colores del proyecto + color del rango
///
/// # Performance
/// - Canvas es la forma más eficiente de renderizar muchas formas en SwiftUI
/// - TimelineView(.animation) sincroniza con el display link
/// - 50 partículas es liviano (~60fps consistente)
private struct ConfettiCanvasView: View {
    let rankColor: Color

    @State private var particles: [ConfettiParticle] = []
    @State private var startTime: Date = .now

    /// Colores variados para el confeti (mezcla del proyecto + extras).
    private var confettiColors: [Color] {
        [
            .appActionPrimary,
            .appMarkGood,
            .appMarkFair,
            rankColor,
            .cyan,
            .white,
            Color(red: 1.0, green: 0.84, blue: 0.0), // Dorado
            Color(red: 1.0, green: 0.4, blue: 0.7)     // Rosa
        ]
    }

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation) { timeline in
                let elapsed = timeline.date.timeIntervalSince(startTime)

                Canvas { context, size in
                    for particle in particles {
                        let state = particle.position(at: elapsed, bounds: size)

                        // Solo renderizar partículas dentro de bounds
                        guard state.y < size.height + 20 else { continue }

                        context.opacity = state.opacity
                        context.translateBy(x: state.x, y: state.y)
                        context.rotate(by: .radians(state.rotation))

                        let rect = CGRect(
                            x: -particle.width / 2,
                            y: -particle.height / 2,
                            width: particle.width,
                            height: particle.height
                        )
                        context.fill(
                            Path(roundedRect: rect, cornerRadius: 1),
                            with: .color(particle.color)
                        )

                        // Reset transforms para próxima partícula
                        context.rotate(by: .radians(-state.rotation))
                        context.translateBy(x: -state.x, y: -state.y)
                    }
                }
            }
            .onAppear {
                let size = geometry.size
                particles = (0..<50).map { _ in
                    ConfettiParticle.random(
                        bounds: size,
                        colors: confettiColors
                    )
                }
                startTime = .now
            }
        }
    }
}

// MARK: - Confetti Particle

/// Modelo de una partícula de confeti con físicas simuladas.
///
/// # Físicas
/// - Gravedad: caída constante (~120 pt/s)
/// - Deriva lateral: movimiento sinusoidal (simula confeti que flota)
/// - Rotación: velocidad angular constante (simula papel girando)
/// - Fade out: desaparece gradualmente después de ~3 segundos
private struct ConfettiParticle {
    /// Posición inicial X (normalizada 0-1 del ancho).
    let startX: CGFloat
    /// Posición inicial Y (arriba de la pantalla).
    let startY: CGFloat
    /// Velocidad de caída (pt/s).
    let fallSpeed: CGFloat
    /// Amplitud de la deriva lateral (pt).
    let driftAmplitude: CGFloat
    /// Frecuencia de la deriva lateral.
    let driftFrequency: CGFloat
    /// Velocidad angular (rad/s).
    let angularVelocity: Double
    /// Tamaño del rectángulo de confeti.
    let width: CGFloat
    let height: CGFloat
    /// Color de esta partícula.
    let color: Color
    /// Delay antes de empezar a caer (s).
    let delay: CGFloat

    /// Calcula la posición de la partícula en un momento dado.
    func position(at time: TimeInterval, bounds: CGSize) -> ParticleState {
        let t = max(CGFloat(time) - delay, 0)
        let gravity: CGFloat = 120

        let x = startX * bounds.width + driftAmplitude * sin(driftFrequency * t)
        let y = startY + fallSpeed * t + 0.5 * gravity * t * t * 0.01
        let rotation = angularVelocity * Double(t)

        // Fade out después de 3 segundos
        let fadeStart: CGFloat = 3.0
        let fadeDuration: CGFloat = 1.5
        let opacity: Double = t < fadeStart ? 1.0 : max(0, Double(1.0 - (t - fadeStart) / fadeDuration))

        return ParticleState(x: x, y: y, rotation: rotation, opacity: opacity)
    }

    /// Genera una partícula con valores aleatorios dentro de los bounds.
    static func random(bounds: CGSize, colors: [Color]) -> ConfettiParticle {
        ConfettiParticle(
            startX: CGFloat.random(in: 0...1),
            startY: CGFloat.random(in: -80...(-20)),
            fallSpeed: CGFloat.random(in: 80...200),
            driftAmplitude: CGFloat.random(in: 15...40),
            driftFrequency: CGFloat.random(in: 1.5...3.5),
            angularVelocity: Double.random(in: -4...4),
            width: CGFloat.random(in: 6...12),
            height: CGFloat.random(in: 4...8),
            color: colors.randomElement() ?? .white,
            delay: CGFloat.random(in: 0...0.8)
        )
    }
}

/// Estado calculado de una partícula en un frame específico.
private struct ParticleState {
    let x: CGFloat
    let y: CGFloat
    let rotation: Double
    let opacity: Double
}

// MARK: - Previews

#Preview("Victoria — Mítico (1 intento)") {
    VictorySplashView(secret: "50317", attempts: 1, onNewGame: {})
}

#Preview("Victoria — Oro (10 intentos)") {
    VictorySplashView(secret: "82946", attempts: 10, onNewGame: {})
}

#Preview("Victoria — Plata (25 intentos)") {
    VictorySplashView(secret: "13579", attempts: 25, onNewGame: {})
}

#Preview("Victoria — Bronce (35 intentos)") {
    VictorySplashView(secret: "24680", attempts: 35, onNewGame: {})
}
