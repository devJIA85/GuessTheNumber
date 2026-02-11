//
//  SplashView.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 11/02/2026.
//

import SwiftUI

// MARK: - SplashView (Splash Screen Animada)

/// Pantalla de splash animada que replica el ícono de la app con animaciones staggered.
///
/// # Secuencia de animación (~1.2s)
/// 1. **Fase 1** (0.40s): ícono fade-in + scale 0.92 → 1.0 con spring
/// 2. **Fase 2** (0.30s): "?" micro-pop scale 1.0 → 1.06 → 1.0 + glass highlight
/// 3. **Fase 3** (0.45s): ícono dissolve (blur + fade) mientras contenido principal aparece
///
/// # Accesibilidad
/// - Si `accessibilityReduceMotion` está habilitado, salta directamente a un fade
///   rápido de 0.3s sin spring ni pop.
///
/// # Liquid Glass (iOS 26+)
/// - Usa `.glassEffect` en el "?" para integración nativa con Liquid Glass.
/// - Glass highlight overlay en Fase 2 para efecto de "pulso" vidrioso.
/// - Fallback iOS <26: shadow sutil y overlay blanco.
///
/// # Integración
/// - Montada como overlay en `RootView`, se auto-remueve cuando `isActive = false`.
/// - `PremiumBackgroundGradient` como fondo para continuidad visual con el launch screen.
struct SplashView: View {

    // MARK: - Interface

    /// Binding que controla la visibilidad de la splash desde `RootView`.
    /// - Se pone en `false` cuando la animación termina.
    @Binding var isActive: Bool

    // MARK: - Environment

    /// Preferencia de accesibilidad: reduce motion.
    /// - Why: Apple HIG requiere respetar esta preferencia.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Animation State

    /// Opacidad del ícono (0 → 1 en Fase 1).
    @State private var iconOpacity: CGFloat = 0

    /// Escala del ícono (0.92 → 1.0 en Fase 1).
    @State private var iconScale: CGFloat = SplashStyle.Scale.initial

    /// Escala del símbolo "?" (1.0 → 1.06 → 1.0 en Fase 2).
    @State private var symbolScale: CGFloat = 1.0

    /// Controla la aparición del highlight glass en Fase 2.
    @State private var showGlassHighlight: Bool = false

    /// Radio de blur para la disolución en Fase 3.
    @State private var dissolveBlur: CGFloat = 0

    /// Opacidad general para la disolución en Fase 3.
    @State private var dissolveOpacity: CGFloat = 1

    // MARK: - Body

    var body: some View {
        ZStack {
            // FONDO: replica PremiumBackgroundGradient para evitar flash blanco.
            // - Why: el static launch screen puede no coincidir exactamente,
            //   este gradiente asegura continuidad visual desde el primer frame.
            PremiumBackgroundGradient()

            // ÍCONO ANIMADO: card centrada con gradiente del app icon.
            iconCard
                .scaleEffect(iconScale)
                .opacity(iconOpacity)
                .blur(radius: dissolveBlur)
        }
        .opacity(dissolveOpacity)
        .ignoresSafeArea()
        .onAppear {
            // Disparar la secuencia de animación apropiada.
            if reduceMotion {
                triggerReducedMotionSequence()
            } else {
                triggerAnimationSequence()
            }
        }
    }

    // MARK: - Icon Card

    /// Card del ícono: gradiente + "?" + dots + glass highlight.
    ///
    /// # Estructura
    /// ```
    /// ZStack {
    ///     RoundedRectangle (gradiente)
    ///     RoundedRectangle (borde glass)
    ///     VStack { "?" + dots }
    ///     glassHighlightOverlay (condicional)
    /// }
    /// ```
    private var iconCard: some View {
        ZStack {
            // Card base con gradiente del ícono (réplica del app icon).
            RoundedRectangle(
                cornerRadius: SplashStyle.Size.iconCornerRadius,
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [
                        SplashStyle.IconColors.lavender,
                        SplashStyle.IconColors.skyBlue,
                        SplashStyle.IconColors.cyan
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(
                width: SplashStyle.Size.iconCard,
                height: SplashStyle.Size.iconCard
            )

            // Borde glass sutil: define los límites de la card.
            // - Why: un borde blanco tenue da profundidad sin competir con el contenido.
            RoundedRectangle(
                cornerRadius: SplashStyle.Size.iconCornerRadius,
                style: .continuous
            )
            .strokeBorder(Color.white.opacity(0.3), lineWidth: 1.5)
            .frame(
                width: SplashStyle.Size.iconCard,
                height: SplashStyle.Size.iconCard
            )

            // Contenido del ícono: "?" + dots decorativos.
            VStack(spacing: 12) {
                questionMarkSymbol
                decorativeDots
            }

            // Glass highlight overlay: aparece en Fase 2 como "pulso" vidrioso.
            if showGlassHighlight {
                glassHighlightOverlay
            }
        }
    }

    // MARK: - Question Mark Symbol

    /// Símbolo "?" con Liquid Glass en iOS 26+ o shadow en iOS <26.
    ///
    /// # iOS 26+
    /// - Usa `.glassEffect(.regular.interactive())` para integración nativa.
    /// - El glass reacciona al material y da profundidad automática.
    ///
    /// # iOS <26
    /// - Shadow blanco sutil para simular profundidad.
    private var questionMarkSymbol: some View {
        Group {
            if #available(iOS 26.0, *) {
                // iOS 26+: Liquid Glass en el "?" para efecto vidrioso nativo.
                Text("?")
                    .font(.system(
                        size: SplashStyle.Size.questionMarkFont,
                        weight: .bold,
                        design: .rounded
                    ))
                    .foregroundStyle(Color.white.opacity(SplashStyle.Opacity.questionMark))
                    .scaleEffect(symbolScale)
                    .glassEffect(
                        .regular.interactive(),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
            } else {
                // iOS <26: fallback con shadow sutil.
                Text("?")
                    .font(.system(
                        size: SplashStyle.Size.questionMarkFont,
                        weight: .bold,
                        design: .rounded
                    ))
                    .foregroundStyle(Color.white.opacity(SplashStyle.Opacity.questionMark))
                    .scaleEffect(symbolScale)
                    .shadow(color: Color.white.opacity(0.3), radius: 8)
            }
        }
    }

    // MARK: - Decorative Dots

    /// 4 puntos decorativos debajo del "?" (réplica del app icon).
    ///
    /// # Diseño
    /// - Blancos con opacidad baja para no competir con el "?".
    /// - Distribuidos en HStack con spacing uniforme.
    private var decorativeDots: some View {
        HStack(spacing: SplashStyle.Size.dotSpacing) {
            ForEach(0..<4, id: \.self) { _ in
                Circle()
                    .fill(SplashStyle.Opacity.dotsColor.opacity(SplashStyle.Opacity.dots))
                    .frame(
                        width: SplashStyle.Size.dot,
                        height: SplashStyle.Size.dot
                    )
            }
        }
    }

    // MARK: - Glass Highlight Overlay

    /// Overlay glass que aparece en Fase 2 como efecto de "pulso".
    ///
    /// # iOS 26+
    /// - Usa `.glassEffect(.regular)` para reflejo vidrioso real.
    ///
    /// # iOS <26
    /// - Fill blanco con opacidad baja como simulación.
    @ViewBuilder
    private var glassHighlightOverlay: some View {
        if #available(iOS 26.0, *) {
            // iOS 26+: glass overlay real con Liquid Glass.
            RoundedRectangle(
                cornerRadius: SplashStyle.Size.iconCornerRadius,
                style: .continuous
            )
            .fill(.clear)
            .glassEffect(
                .regular,
                in: RoundedRectangle(
                    cornerRadius: SplashStyle.Size.iconCornerRadius,
                    style: .continuous
                )
            )
            .frame(
                width: SplashStyle.Size.iconCard,
                height: SplashStyle.Size.iconCard
            )
            .opacity(0.3)
            .transition(.opacity)
        } else {
            // iOS <26: overlay blanco sutil como simulación de glass.
            RoundedRectangle(
                cornerRadius: SplashStyle.Size.iconCornerRadius,
                style: .continuous
            )
            .fill(Color.white.opacity(0.15))
            .frame(
                width: SplashStyle.Size.iconCard,
                height: SplashStyle.Size.iconCard
            )
            .transition(.opacity)
        }
    }

    // MARK: - Animation Sequences

    /// Secuencia de animación completa (~1.2s).
    ///
    /// # Timeline
    /// ```
    /// t=0.00s  Fase 1: spring → iconOpacity 0→1, iconScale 0.92→1.0
    /// t=0.42s  Fase 2: spring → symbolScale pop 1.0→1.06→1.0 + glass highlight
    /// t=0.75s  Fase 3: easeOut → dissolveBlur 0→10, dissolveOpacity 1→0
    /// t=1.20s  isActive = false
    /// ```
    ///
    /// # Patrón
    /// - Usa `DispatchQueue.main.asyncAfter` + `withAnimation` (mismo patrón que `VictorySplashView`).
    /// - Why: no usamos `Task.sleep` porque no necesitamos cancelación y el patrón
    ///   de dispatch es más predecible para timing de animaciones.
    private func triggerAnimationSequence() {
        // FASE 1: Fade-in + scale-up del ícono con spring.
        // - Spring con damping 0.75: rebote mínimo, se asienta rápido.
        withAnimation(.spring(response: SplashStyle.Duration.iconEntrance, dampingFraction: 0.75)) {
            iconOpacity = 1.0
            iconScale = SplashStyle.Scale.target
        }

        // FASE 2: Micro-pop del "?" + glass highlight.
        // - t=0.42s: empieza después de que el spring de entrada se estabilice.
        DispatchQueue.main.asyncAfter(deadline: .now() + SplashStyle.Duration.delayBeforePop) {
            // Pop del "?": spring con damping bajo para rebote visible.
            withAnimation(.spring(response: SplashStyle.Duration.symbolPop, dampingFraction: 0.5)) {
                symbolScale = SplashStyle.Scale.popPeak
            }

            // Glass highlight aparece con fade sutil.
            withAnimation(.easeIn(duration: 0.15)) {
                showGlassHighlight = true
            }

            // "?" vuelve a escala normal después del pico.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    symbolScale = SplashStyle.Scale.target
                }
            }
        }

        // FASE 3: Disolución + crossfade a contenido principal.
        // - t=0.75s: el pop ya terminó, empezamos la salida.
        DispatchQueue.main.asyncAfter(deadline: .now() + SplashStyle.Duration.delayBeforeDissolve) {
            withAnimation(.easeOut(duration: SplashStyle.Duration.dissolve)) {
                dissolveBlur = 10
                dissolveOpacity = 0
            }

            // Marcar splash como inactiva al final de la disolución.
            // - Why: esperamos a que la opacidad llegue a 0 para evitar cortes visuales.
            DispatchQueue.main.asyncAfter(deadline: .now() + SplashStyle.Duration.dissolve) {
                isActive = false
            }
        }
    }

    /// Secuencia reducida para `accessibilityReduceMotion`.
    ///
    /// # Comportamiento
    /// - Ícono aparece instantáneamente (sin spring ni escala).
    /// - Solo un fade-out rápido de 0.3s.
    /// - Sin micro-pop ni glass highlight.
    ///
    /// # Por qué no saltamos directamente
    /// - Mostrar el ícono brevemente mantiene el branding visible.
    /// - El fade-out es la forma más sutil de transición.
    private func triggerReducedMotionSequence() {
        // Ícono aparece instantáneamente.
        iconOpacity = 1.0
        iconScale = SplashStyle.Scale.target

        // Después de un momento breve, fade-out.
        DispatchQueue.main.asyncAfter(deadline: .now() + SplashStyle.Duration.reduceMotionTotal) {
            withAnimation(.easeOut(duration: SplashStyle.Duration.reduceMotionTotal)) {
                dissolveOpacity = 0
            }

            // Remover splash al final del fade.
            DispatchQueue.main.asyncAfter(deadline: .now() + SplashStyle.Duration.reduceMotionTotal) {
                isActive = false
            }
        }
    }
}

// MARK: - Preview

#Preview("SplashView - Animación completa") {
    @Previewable @State var isActive = true

    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()

        if isActive {
            SplashView(isActive: $isActive)
        } else {
            Text("Contenido principal")
                .font(.largeTitle)
        }
    }
}

#Preview("SplashView - Ícono estático") {
    SplashView(isActive: .constant(true))
}
