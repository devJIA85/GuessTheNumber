//
//  RootView.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 11/02/2026.
//

import SwiftUI
import SwiftData

// MARK: - RootView (Contenedor raíz con Splash)

/// Vista raíz que orquesta la splash animada sobre el contenido principal.
///
/// # Arquitectura
/// - `GameView` se monta **siempre** (no se retrasa la carga).
/// - `SplashView` se superpone como overlay y se auto-remueve al finalizar.
/// - El estado `isSplashActive` vive aquí como fuente de verdad.
///
/// # Por qué overlay y no condicional
/// - El contenido principal (`GameView`) necesita empezar su `.task { }` para cargar
///   la partida mientras la splash se muestra.
/// - Si usáramos if/else, `GameView` no existiría hasta que la splash termine,
///   causando un delay visible al cargar la partida.
///
/// # Flujo
/// 1. App inicia → `RootView` se monta.
/// 2. `GameView` comienza a cargar datos en background.
/// 3. `SplashView` cubre todo con la animación (~1.2s).
/// 4. Al terminar, `isSplashActive = false` → splash se remueve.
/// 5. `GameView` ya está listo y visible.
struct RootView: View {

    // MARK: - State

    /// Controla la visibilidad de la splash screen.
    /// - Inicia en `true` y se pone en `false` cuando la animación termina.
    @State private var isSplashActive = true

    // MARK: - Body

    var body: some View {
        ZStack {
            // CONTENIDO PRINCIPAL: siempre montado para que .task inicie de inmediato.
            // - Why: GameView.task { } llama a env.gameActor para cargar/crear la partida.
            //   Si esperamos a que la splash termine, hay un delay visible.
            GameView()
                // Accesibilidad: ocultar contenido principal mientras splash está activa.
                // - Why: evita que VoiceOver lea el juego mientras el usuario ve la splash.
                .accessibilityHidden(isSplashActive)

            // SPLASH OVERLAY: se auto-remueve cuando isActive se pone en false.
            if isSplashActive {
                SplashView(isActive: $isSplashActive)
                    // Transición de salida: .identity porque SplashView maneja su propia
                    // animación de salida (dissolve). No queremos que SwiftUI agregue
                    // una transición por defecto que interfiera.
                    .transition(.identity)
                    // Evitar que taps atraviesen la splash al contenido.
                    // - Why: sin esto, el usuario podría interactuar con GameView
                    //   mientras la splash está visible.
                    .allowsHitTesting(true)
            }
        }
    }
}

// MARK: - Preview

#Preview("RootView - Con Splash") {
    let container = ModelContainerFactory.make(isInMemory: true)
    let env = AppEnvironment(modelContainer: container)

    RootView()
        .environment(\.appEnvironment, env)
        .modelContainer(container)
}
