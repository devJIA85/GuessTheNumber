//
//  SplashStyle.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 11/02/2026.
//

import SwiftUI

// MARK: - Splash Screen Design Tokens

/// Tokens de diseño centralizados para la pantalla de splash animada.
///
/// # Filosofía
/// - Constantes separadas del layout para facilitar ajustes de timing y diseño.
/// - Misma convención de enums sin instancia que `AppTheme`.
/// - Cualquier ajuste de timing o color es un cambio de una sola línea.
///
/// # Por qué existe
/// - Evita magic numbers dispersos en `SplashView`.
/// - Permite que diseño y desarrollo iteren sin tocar lógica de animación.
enum SplashStyle {

    // MARK: - Duraciones de animación

    /// Timing de cada fase de la secuencia de animación.
    ///
    /// # Secuencia completa (~1.2s)
    /// ```
    /// t=0.00s  Fase 1: fade-in + scale spring
    /// t=0.42s  Fase 2: micro-pop del "?"
    /// t=0.75s  Fase 3: disolución + crossfade
    /// t=1.20s  Splash se remueve
    /// ```
    enum Duration {
        /// Fase 1: fade-in + scale-up del ícono (spring).
        static let iconEntrance: CGFloat = 0.40

        /// Fase 2: micro-pop del "?" (scale 1.0 → 1.06 → 1.0).
        static let symbolPop: CGFloat = 0.30

        /// Fase 3: disolución del ícono + crossfade a contenido.
        static let dissolve: CGFloat = 0.45

        /// Delay entre Fase 1 y Fase 2.
        /// - Why: espera que el spring de entrada se estabilice antes del pop.
        static let delayBeforePop: CGFloat = 0.42

        /// Delay entre inicio y Fase 3.
        /// - Why: el pop termina ~0.72s, y empezamos dissolve en 0.75s para overlap sutil.
        static let delayBeforeDissolve: CGFloat = 0.75

        /// Duración total reducida para `accessibilityReduceMotion`.
        /// - Why: Apple HIG requiere respetar esta preferencia. Solo fade rápido.
        static let reduceMotionTotal: CGFloat = 0.3
    }

    // MARK: - Escalas

    /// Escalas para las animaciones del ícono.
    enum Scale {
        /// Escala inicial del ícono (ligeramente reducido).
        /// - Why: empezar en 0.92 y subir a 1.0 da sensación de "aparecer" orgánico.
        static let initial: CGFloat = 0.92

        /// Escala objetivo del ícono (tamaño real).
        static let target: CGFloat = 1.0

        /// Escala pico del micro-pop del "?".
        /// - Why: 1.06 es sutil pero perceptible. Más de 1.10 se siente exagerado.
        static let popPeak: CGFloat = 1.06
    }

    // MARK: - Colores del ícono

    /// Gradiente vertical del ícono (réplica del app icon).
    ///
    /// # Colores
    /// - Top: lavanda suave → Mid: azul cielo → Bottom: cyan fresco
    /// - Estos colores replican el ícono real de la app.
    enum IconColors {
        /// Top del gradiente: lavanda suave.
        static let lavender = Color(red: 0.84, green: 0.78, blue: 0.94)   // #D6C8F0

        /// Medio del gradiente: azul cielo.
        static let skyBlue  = Color(red: 0.66, green: 0.85, blue: 0.96)   // #A9D9F5

        /// Bottom del gradiente: cyan fresco.
        static let cyan     = Color(red: 0.44, green: 0.80, blue: 0.95)   // #6FCDF2
    }

    // MARK: - Opacidades

    /// Opacidades para los elementos visuales del ícono.
    enum Opacity {
        /// Opacidad del símbolo "?" (blanco).
        static let questionMark: CGFloat = 0.92

        /// Opacidad de los puntos decorativos.
        static let dots: CGFloat = 0.6

        /// Color de los puntos (blanco soft).
        static let dotsColor = Color(red: 0.96, green: 0.97, blue: 1.0)  // #F4F8FF
    }

    // MARK: - Dimensiones

    /// Tamaños fijos para el ícono y sus elementos.
    enum Size {
        /// Tamaño de la card del ícono.
        /// - Why: 140pt es suficiente para que el ícono se vea prominente centrado.
        static let iconCard: CGFloat = 200

        /// Corner radius del ícono (super-rounded, icon-like).
        /// - Why: 32pt da la forma de "squircle" de los iconos de iOS.
        static let iconCornerRadius: CGFloat = 44

        /// Tamaño del font del símbolo "?".
        static let questionMarkFont: CGFloat = 104

        /// Tamaño de cada punto decorativo.
        static let dot: CGFloat = 8

        /// Spacing entre puntos.
        static let dotSpacing: CGFloat = 12
    }
}
